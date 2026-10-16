# Projects are archived, not deleted: an archived project keeps its days and entries,
#   stays readable and exportable, but takes no new or changed entries (app/policies).
#   The slug is set once and survives a rename, so links to the project keep working.
#
class Project < ApplicationRecord
  # The slug is the second segment of every project URL (/acme/website/days/2026-10-15),
  #   next to the org-level pages /acme/members and /acme/settings.
  RESERVED_SLUGS = %w[invitations members projects settings].freeze

  belongs_to :org

  # days and their entries are history: archive the project instead (the DB FK refuses as well)
  has_many :days, dependent: :restrict_with_exception
  has_many :participants, inverse_of: :project, dependent: :destroy
  has_many :invitations, dependent: :destroy
  has_many :access_requests, inverse_of: :project, dependent: :destroy

  has_many :entries, through: :days
  has_many :members, through: :participants

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  before_validation :set_slug, on: :create

  validates :name, presence: true, uniqueness: { scope: :org_id }
  validates :slug, uniqueness: { scope: :org_id }, exclusion: { in: RESERVED_SLUGS }

  def to_param
    slug
  end

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current) unless archived?
  end

  def unarchive!
    update!(archived_at: nil)
  end

  private

  def set_slug
    new_slug = name.to_s.parameterize

    new_slug = "#{new_slug}-#{rand(99)}" while RESERVED_SLUGS.include?(new_slug) || Project.exists?(org_id:, slug: new_slug)

    self.slug = new_slug
  end
end
