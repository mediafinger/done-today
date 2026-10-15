class Project < ApplicationRecord
  # The slug is the second segment of every project URL (/acme/website/days/2026-10-15),
  #   next to the org-level pages /acme/members and /acme/settings.
  RESERVED_SLUGS = %w[members projects settings].freeze

  belongs_to :org

  has_many :days, dependent: :destroy
  has_many :participants, inverse_of: :project, dependent: :destroy

  has_many :entries, through: :days
  has_many :members, through: :participants

  before_validation :set_slug, on: :create

  validates :name, presence: true, uniqueness: { scope: :org_id }
  validates :slug, uniqueness: { scope: :org_id }, exclusion: { in: RESERVED_SLUGS }

  def to_param
    slug
  end

  private

  def set_slug
    new_slug = name.to_s.parameterize

    new_slug = "#{new_slug}-#{rand(99)}" while RESERVED_SLUGS.include?(new_slug) || Project.exists?(org_id:, slug: new_slug)

    self.slug = new_slug
  end
end
