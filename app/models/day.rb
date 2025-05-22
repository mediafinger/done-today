class Day < ApplicationRecord
  belongs_to :org
  belongs_to :project, inverse_of: :days

  has_many :entries, inverse_of: :day, dependent: :destroy

  before_validation :set_org

  validates :date, presence: true

  private

  def set_org
    self.org ||= project.org
  end
end
