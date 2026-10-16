# participant - can create new entries, can read existing entries, can edit their own entries
# observer - can read existing entries
# owner - can create new entries, can read existing entries, can edit all entries,
#         can manage project, can manage participants (as can org-owner)
#
# What the roles allow is decided in app/policies.
#
# Removing a participant takes their access, their entries stay in the project
#   (entries belong to the member and the day, not to the participation).
#
class Participant < ApplicationRecord
  VALID_ROLES = %w[participant observer owner].freeze
  # strongest first, the UI gives each participant one of them
  RANKED_ROLES = %w[owner participant observer].freeze

  belongs_to :org
  belongs_to :project, inverse_of: :participants
  belongs_to :member, inverse_of: :participations

  scope :includes_a_role_of, ->(roles) { roles ? where("roles && ARRAY[?]::text[]", roles) : all }
  scope :includes_all_roles, ->(roles) { roles ? where("roles @> ARRAY[?]::text[]", roles) : all }

  before_validation :set_org

  validates :member, uniqueness: { scope: :project_id } # mirrors the unique DB index
  validate :member_of_the_projects_org
  validates :roles, presence: true, array_inclusion: {
    in: VALID_ROLES, message: "%{rejected_values} not allowed, roles must be in #{VALID_ROLES}"
  }

  def role
    RANKED_ROLES.find { roles.include?(it) }
  end

  private

  def member_of_the_projects_org
    errors.add(:member, :invalid) if member && project && member.org_id != project.org_id
  end

  def set_org
    self.org ||= project.org
  end
end
