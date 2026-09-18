require "strscan"

# Parses the free text of an `Entry#log` into the structured values the
# time-tracking features need: tags, day boundaries, a time range and a duration.
#
# This is a value object (a PORO, not an Active Record model). It never raises and
# never rejects input -- the log text is always saved verbatim, whatever the markup
# says, because a typo in `for~1hh` must not block `entry.save` while someone is
# typing fast. Anything that does not parse becomes an advisory `Issue`, and the
# text that produced it stays prose.
#
# `#segments` is the single source of truth: the text is tokenized exactly once and
# every other reader is derived from it. The HTML renderer consumes the same
# segments, so what is displayed can never drift from what was extracted.
#
#   log = EntryLog.new("#PR123 review from@11:00 to@12:30")
#   log.tags              # => ["pr123"]
#   log.duration_minutes  # => 90
#
class EntryLog
  # A segment is a tuple whose first element is its type and whose **last element is
  # always the verbatim source text**, so `segments.map(&:last).join` reproduces the
  # input exactly:
  #
  #   [ :text, "fixed the "          ]
  #   [ :tag,  "PR123", "#PR123"     ]   # the name keeps its casing, `#tags` downcases
  #   [ :time, :for, 90, "for~1h30m" ]   # kind is :start, :end, :from, :to or :for
  #
  # Markup that does not parse (`from@10:75`, `for~1hh`) is folded into the
  # surrounding `:text` segment and reported through `#issues`.

  Issue = Data.define(:code, :severity, :message)

  # Hours run to 29 rather than 23: `end@25:30` is an unambiguous way to say "01:30
  # the next day" and needs no date arithmetic. An activity that keeps running past
  # that gets a new entry on the next day.
  MAX_HOUR = 29
  MAX_MINUTE = 59

  # A token may only start at the beginning of the string or right after whitespace --
  # `(?<![^\s])`, "not preceded by a non-whitespace character". That is what makes
  # `x#b` prose rather than a tag. The rule is applied in `#tokenize` instead of being
  # embedded in the patterns, because StringScanner matches from its pointer and
  # cannot look behind it: an inline lookbehind would silently always succeed.
  #
  TAG      = /\#(?<name>\p{Alnum}[\p{Alnum}_\/-]*)/
  TIME     = /(?<kind>start|end|from|to)@(?<h>\d{1,2}):(?<m>\d{2})\b/i
  DURATION = /for~(?=\d)(?:(?<h>\d+)h)?(?:(?<m>\d+)m)?(?![\p{Alnum}])/i

  # Fallbacks, tried only where the strict patterns fail. They recognise "this was
  # meant to be time markup" so the typo can be reported instead of silently ignored.
  # `to@bob` does not look like a time at all and stays prose without an issue.
  MALFORMED_TIME     = /(?<kind>start|end|from|to)@(?=[\d:])[\p{Alnum}:]*/i
  MALFORMED_DURATION = /for~[\p{Alnum}]*/i

  TIME_KINDS = { "start" => :start, "end" => :end, "from" => :from, "to" => :to }.freeze

  attr_reader :text, :segments, :issues,
              :day_start_minutes, :day_end_minutes, :from_minutes, :to_minutes, :duration_minutes

  # `on_past_day:` only affects severity: an unclosed `from@` is normal while the day
  # is still running, and worth a warning once the day is over.
  #
  def initialize(text, on_past_day: false)
    @text = text.to_s
    @on_past_day = on_past_day
    @issues = []
    @segments = tokenize
    extract
  end

  def tags
    @tags ||= segments.filter_map { |type, name, _raw| name.downcase if type == :tag }.uniq
  end

  # True when the log carries markup only -- `start@09:00`, or `#break for~30m` --
  # with no prose around it.
  def marker_only?
    segments.any? && segments.none? { |type, value, _raw| type == :text && value.match?(/\S/) }
  end

  private

  attr_reader :on_past_day

  def tokenize
    scanner = StringScanner.new(text)
    segments = []
    pending = +""
    at_boundary = true

    flush = lambda do
      segments << [ :text, pending.dup ] unless pending.empty?
      pending.clear
    end

    until scanner.eos?
      token = at_boundary ? scan_token(scanner) : nil

      consumed =
        case token
        when nil    then scanner.getch                        # ordinary prose, one character at a time
        when String then token                                # markup that has to stay prose
        else             token.last
        end

      if token.is_a?(Array)
        flush.call
        segments << token
      else
        pending << consumed
      end

      at_boundary = consumed.match?(/\s\z/)
    end

    flush.call
    segments.freeze
  end

  # Returns a segment, or the raw text of markup that has to stay prose, or nil when
  # nothing matches at the scanner's position.
  def scan_token(scanner)
    if (raw = scanner.scan(TAG))
      [ :tag, scanner[:name], raw ]
    elsif (raw = scanner.scan(TIME))
      time_token(scanner, raw)
    elsif (raw = scanner.scan(DURATION))
      [ :time, :for, (scanner[:h].to_i * 60) + scanner[:m].to_i, raw ]
    elsif (raw = scanner.scan(MALFORMED_TIME))
      invalid_time(raw)
    elsif (raw = scanner.scan(MALFORMED_DURATION))
      invalid_duration(raw)
    end
  end

  def time_token(scanner, raw)
    hours = scanner[:h].to_i
    minutes = scanner[:m].to_i

    return invalid_time(raw) if hours > MAX_HOUR || minutes > MAX_MINUTE

    [ :time, TIME_KINDS.fetch(scanner[:kind].downcase), (hours * 60) + minutes, raw ]
  end

  def invalid_time(raw)
    add_issue(:invalid_time, :warning, "#{raw} is not a valid time, it is kept as text")
    raw
  end

  def invalid_duration(raw)
    add_issue(:invalid_duration, :warning, "#{raw} is not a valid duration, it is kept as text")
    raw
  end

  def extract
    @day_start_minutes = single(:start)
    @day_end_minutes = single(:end)
    @from_minutes = single(:from)
    @to_minutes = single(:to)
    @duration_minutes = resolve_duration
    check_open_range
  end

  def times
    @times ||= segments.filter_map { |type, kind, minutes, _raw| [ kind, minutes ] if type == :time }
  end

  # The first marker of a kind wins; a repeat is almost certainly a slip of the
  # keyboard, so it is reported rather than silently overwriting the first one.
  def single(kind)
    found = times.select { |time_kind, _minutes| time_kind == kind }

    add_issue(:duplicate_marker, :warning, "#{kind}@ is given more than once, the first one is used") if found.many?

    found.first&.last
  end

  def resolve_duration
    explicit = zeroless(single(:for), "for~ is an empty duration, it is ignored")
    ranged = range_duration

    if ranged && explicit && ranged != explicit
      add_issue(:conflicting_duration, :warning,
                "for~ says #{explicit} minutes but from@ / to@ span #{ranged}, the range wins")
    end

    ranged || explicit
  end

  def range_duration
    return nil unless from_minutes && to_minutes

    span = to_minutes - from_minutes

    if span.negative?
      add_issue(:negative_range, :warning, "to@ is earlier than from@")
      return nil
    end

    zeroless(span, "from@ and to@ are the same time")
  end

  # A duration of zero says nothing about how long something took, so it is reported
  # and dropped instead of being stored as a 0 that later sums would swallow.
  def zeroless(minutes, message)
    return minutes unless minutes&.zero?

    add_issue(:zero_duration, :warning, message)
    nil
  end

  def check_open_range
    return unless from_minutes
    return if to_minutes || times.any? { |kind, _minutes| kind == :for }

    add_issue(:open_range, on_past_day ? :warning : :info, "from@ has no to@ or for~ yet")
  end

  def add_issue(code, severity, message)
    @issues << Issue.new(code:, severity:, message:)
  end
end
