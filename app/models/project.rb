# Projects are archived, not deleted: an archived project keeps its days and entries,
#   stays readable and exportable, but takes no new or changed entries (app/policies).
#   The slug is set once and survives a rename, so links to the project keep working.
#
class Project < ApplicationRecord
  include Sluggable

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

  validates :name, presence: true, uniqueness: { scope: :org_id }
  validates :slug, uniqueness: { scope: :org_id }
  validates :times_required, inclusion: [ true, false ]

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

  def slug_scope
    Project.where(org_id:)
  end
end
