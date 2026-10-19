# A week, a month or a year, as reports take it from the URL:
#   `?week=2026-W42`, `?month=2026-10` or `?year=2026`, the current month without one.
#
#   period = ReportPeriod.from_params({ week: "2026-W42" }, today: Time.zone.today)
#   period.range # => 2026-10-12..2026-10-18
#
class ReportPeriod
  # the first one given wins
  KINDS = %i[week month year].freeze

  FORMATS = { week: PeriodSummary::WEEK_PARAM, month: "%Y-%m", year: "%Y" }.freeze

  # strptime alone takes `26` for the year 26 and `2026x` for 2026
  PATTERNS = { week: /\A\d{4}-W\d{2}\z/, month: /\A\d{4}-\d{2}\z/, year: /\A\d{4}\z/ }.freeze

  attr_reader :kind, :start

  def self.kind_in(params)
    KINDS.find { |kind| params[kind].present? }
  end

  # nil when the period in the params cannot be read
  def self.from_params(params, today:)
    kind = kind_in(params)
    return new(:month, today) unless kind

    value = params[kind].to_s
    return nil unless value.match?(PATTERNS.fetch(kind))

    new(kind, Date.strptime(value, FORMATS.fetch(kind)))
  rescue Date::Error
    nil
  end

  # `date` is any day of the period
  def initialize(kind, date)
    @kind = kind
    @start =
      case kind
      when :week  then date.beginning_of_week(:monday)
      when :month then date.beginning_of_month
      when :year  then date.beginning_of_year
      end
  end

  def range
    start..finish
  end

  def finish
    case kind
    when :week  then start.end_of_week(:monday)
    when :month then start.end_of_month
    when :year  then start.end_of_year
    end
  end

  def label
    start.strftime(FORMATS.fetch(kind))
  end

  def param
    { kind => label }
  end

  def previous
    self.class.new(kind, start - 1)
  end

  def following
    self.class.new(kind, finish + 1)
  end

  # The period of another kind around today, while today lies in this one, else around its start.
  def as(other_kind, today:)
    self.class.new(other_kind, range.cover?(today) ? today : start)
  end
end
