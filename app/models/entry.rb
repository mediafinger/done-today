class Entry < ApplicationRecord
  STATES = %w[todo doing done].freeze

  belongs_to :day
  belongs_to :org
  belongs_to :member

  validates :log, presence: true
  validates :status, presence: true, inclusion: { in: STATES }
end
