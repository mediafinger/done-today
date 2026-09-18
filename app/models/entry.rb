class Entry < ApplicationRecord
  STATES = %w[todo doing done].freeze

  belongs_to :day
  belongs_to :org
  belongs_to :member

  has_one :project, through: :day

  before_validation :set_org

  validates :log, presence: true, length: { in: 3..500 } # the entry form sets the same bounds
  validates :status, presence: true, inclusion: { in: STATES }

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

  def set_org
    self.org ||= day.org
  end
end
