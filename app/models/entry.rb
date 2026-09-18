class Entry < ApplicationRecord
  STATES = %w[todo doing done].freeze

  # The columns `EntryLog` fills in. Each one is named after the reader it comes
  # from, which is what lets `#parse_log` and `rake time_tracking:backfill` work
  # from this one list instead of two copies that can drift apart.
  PARSED_COLUMNS = %w[tags day_start_minutes day_end_minutes from_minutes to_minutes duration_minutes].freeze

  belongs_to :day
  belongs_to :org
  belongs_to :member

  has_one :project, through: :day

  before_validation :set_org
  before_validation :parse_log, if: :log_changed?

  validates :log, presence: true, length: { in: 3..500 } # the entry form sets the same bounds
  validates :status, presence: true, inclusion: { in: STATES }

  # The parsed view of `log`. The columns below are only its projection for SQL to
  # query -- anything reading the markup itself (the renderer, the issue list) goes
  # through here, so it always agrees with the text as it stands right now.
  #
  def parsed
    return @parsed if defined?(@parsed) && @parsed_source == log

    @parsed_source = log
    @parsed = EntryLog.new(log.to_s, on_past_day: day.present? && past?)
  end

  def todo?
    status == "todo"
  end

  def doing?
    status == "doing"
  end

  def done?
    status == "done"
  end

  # `Time.zone` is pinned to AppConf.timezone, so these agree with the date the
  #   user sees in the navigation regardless of the server's own zone
  #
  def today?
    Time.zone.today == day.date
  end

  def future?
    Time.zone.today < day.date
  end

  def past?
    Time.zone.today > day.date
  end

  private

  def parse_log
    PARSED_COLUMNS.each { |column| self[column] = parsed.public_send(column) }
  end

  def set_org
    self.org ||= day.org
  end
end
