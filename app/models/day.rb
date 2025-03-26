class Day < ApplicationRecord
  belongs_to :org
  belongs_to :project, inverse_of: :days

  has_many :entries, inverse_of: :day, dependent: :destroy

  validates :date, presence: true
end
