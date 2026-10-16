# What the CSV exports share: how a PeriodSummary row turns into hours and tags,
# and how names travel into a filename.
#
module CsvExport
  # `#break` is not work, and TimeSummary has already subtracted it from the hours,
  #   so listing it among the topics worked on would be misleading.
  EXCLUDED_TAGS = %w[break].freeze

  TAG_LIMIT = 20

  private

  def hours(row)
    (row.total_minutes.to_i / 60.0).round(2)
  end

  def tags(row)
    row.tag_counts
      .except(*EXCLUDED_TAGS)
      .keys
      .first(TAG_LIMIT)
      .map { |tag| "##{tag}" }
      .join(" ")
  end

  # Names travel into a filename, where spaces and slashes have no business.
  def slug(name)
    name.parameterize
  end
end
