class Project < ApplicationRecord
  belongs_to :org

  has_many :days, dependent: :destroy
  has_many :participants, inverse_of: :project, dependent: :destroy

  has_many :entries, through: :days
  has_many :members, through: :participants

  before_validation :set_slug, on: :create

  validates :name, presence: true, uniqueness: { scope: :org_id }
  validates :slug, uniqueness: { scope: :org_id }

  private

  def set_slug
    new_slug = name.to_s.parameterize

    new_slug = "#{new_slug}-#{rand(99)}" while Project.exists?(org_id:, slug: new_slug)

    self.slug = new_slug
  end
end
