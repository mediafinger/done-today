module EntriesHelper
  # The entry list shows a variable number of leading meta columns (date, project,
  #   member) before the log and the status buttons. Composing the track list here
  #   replaces the .left-aligned-grid-2 ... -5 classes, which needed a new CSS rule
  #   for every column that gets added.
  #
  META_COLUMN = "minmax(4rem, max-content)"
  LOG_COLUMN = "1fr"
  STATUS_COLUMN = "minmax(8rem, 25%)"

  def entry_grid_style(meta_columns:)
    tracks = ([ META_COLUMN ] * meta_columns) + [ LOG_COLUMN, STATUS_COLUMN ]

    "grid-template-columns: #{tracks.join(' ')};"
  end

  # Links a tag to the page listing its entries. The project only goes into the URL
  #   when it is not the current one -- the tag page falls back to that anyway.
  #
  def tag_link(tag, project:, label: "##{tag}")
    project_id = project.id unless project == current_project

    link_to label, entries_path(tag:, mode: "read", project_id:), class: "tag"
  end

  # The log with its #tags linked. Walks the segments EntryLog tokenized, so a
  #   linked tag is exactly what was stored as one; every other segment goes through
  #   safe_join and is escaped -- the log itself is never marked html_safe.
  #
  def render_log(entry)
    safe_join(
      entry.parsed.segments.map do |segment|
        type, raw = segment.first, segment.last

        type == :tag ? tag_link(segment[1].downcase, project: entry.day.project, label: raw) : raw
      end
    )
  end

  # Minutes since midnight as a clock time: 570 => "09:30". Hours run past 23
  #   on purpose (`end@25:30`, see EntryLog::MAX_HOUR), so they are not wrapped.
  #
  def format_clock(minutes)
    return "…" if minutes.nil?

    format("%02d:%02d", *minutes.divmod(60))
  end

  # A duration in the notation `for~` accepts: 90 => "1h30m", 60 => "1h", 45 => "45m".
  #
  def format_minutes(minutes)
    hours, rest = minutes.divmod(60)

    return "#{rest}m" if hours.zero?

    rest.zero? ? "#{hours}h" : "#{hours}h#{rest}m"
  end

  # An ISO calendar week, labelled with its week-based year: the week of
  #   2027-01-01 is "2026 / w53", as that Friday still belongs to 2026's last week.
  #
  def week_label(date)
    date.strftime("%G / w%V")
  end

  # The same week the way `?week=` takes it: "2026-W39".
  #
  def week_param(date)
    date.strftime(PeriodSummary::WEEK_PARAM)
  end

  # The heading of a period on the project page: a week links to its entries,
  #   a month names itself and links its first and last calendar week --
  #   "2026-09 (w36 - w40)".
  #
  def period_heading(period, view:, project:)
    case view
    when "weeks"
      link_to week_label(period.start), entries_path(week: week_param(period.start), project_id: project.id),
        method: :get, class: "camouflage s-link"
    when "months"
      weeks = [ period.start, period.start.end_of_month ].map do |date|
        # no `s-link` of their own: its 65% font size would shrink them a second time
        link_to date.strftime("w%V"), entries_path(week: week_param(date), project_id: project.id), method: :get, class: "camouflage"
      end

      tag.span(safe_join([ period.start.strftime("%Y-%m"), " (", weeks.first, " - ", weeks.last, ")" ]), class: "s-link")
    end
  end
end
