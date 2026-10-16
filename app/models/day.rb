class Day < ApplicationRecord
  belongs_to :org
  belongs_to :project, inverse_of: :days

  # entries are history (the DB FK refuses as well)
  has_many :entries, inverse_of: :day, dependent: :restrict_with_exception

  before_validation :set_org

  validates :date, presence: true, uniqueness: { scope: :project_id } # mirrors the unique DB index

  private

  def set_org
    self.org ||= project.org
  end
end
