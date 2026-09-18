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
end
