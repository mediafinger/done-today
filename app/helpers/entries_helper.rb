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
end
