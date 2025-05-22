class Entry < ApplicationRecord
  STATES = %w[todo doing done].freeze

  belongs_to :day
  belongs_to :org
  belongs_to :member

  has_one :project, through: :day

  before_validation :set_org

  validates :log, presence: true
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

  def today?
    Time.current.to_date == day.date # TODO: timezone correction
  end

  def future?
    Time.current.to_date < day.date # TODO: timezone correction
  end

  def past?
    Time.current.to_date > day.date # TODO: timezone correction
  end

  private

  def set_org
    self.org ||= day.org
  end
end
