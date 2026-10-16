# participant - can create new entries, can read existing entries, can edit their own entries
# observer - can read existing entries
# lead - can create new entries, can read existing entries, can edit all entries,
#        can manage project, can manage participants (as can org managers and owners)
#
# What the roles allow is decided in app/policies.
#
# Removing a participant takes their access, their entries stay in the project
#   (entries belong to the member and the day, not to the participation).
#   A guest never leads a project, and without a project they are deactivated.
#
class Participant < ApplicationRecord
  VALID_ROLES = %w[participant observer lead].freeze
  # strongest first, the UI gives each participant one of them
  RANKED_ROLES = %w[lead participant observer].freeze
  # a guest never leads a project
  GUEST_ROLES = %w[participant observer].freeze

  belongs_to :org
  belongs_to :project, inverse_of: :participants
  belongs_to :member, inverse_of: :participations

  scope :includes_a_role_of, ->(roles) { roles ? where("roles && ARRAY[?]::text[]", roles) : all }
  scope :includes_all_roles, ->(roles) { roles ? where("roles @> ARRAY[?]::text[]", roles) : all }

  before_validation :set_org

  after_destroy :archive_guest_without_project, unless: :destroyed_by_association

  validates :member, uniqueness: { scope: :project_id } # mirrors the unique DB index
  validate :member_of_the_projects_org
  validate :guest_leads_no_project
  validates :roles, presence: true, array_inclusion: {
    in: VALID_ROLES, message: "%{rejected_values} not allowed, roles must be in #{VALID_ROLES}"
  }

  def role
    RANKED_ROLES.find { roles.include?(it) }
  end

  private

  # project leads manage participants and see the org's members, guests must not
  def guest_leads_no_project
    errors.add(:roles, :guest_lead) if member&.guest? && roles.include?("lead")
  end

  # a guest sees only their projects: without one they have no business in the org
  def archive_guest_without_project
    member.archive! if member.guest? && !member.participations.exists?
  end

  def member_of_the_projects_org
    errors.add(:member, :invalid) if member && project && member.org_id != project.org_id
  end

  def set_org
    self.org ||= project.org
  end
end
