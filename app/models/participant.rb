# Every participant has one project role:
#   observer - can read existing entries
#   participant - can create new entries, can read existing entries, can edit their own entries
#   lead - can create new entries, can read existing entries, can edit all entries,
#          can manage project, can manage participants (as can org managers and owners)
#
# What the roles allow is decided in app/policies.
#
# Removing a participant takes their access, their entries stay in the project
#   (entries belong to the member and the day, not to the participation).
#   A guest never leads a project, and without a project they are deactivated.
#
class Participant < ApplicationRecord
  # weakest first, the order of the Postgres enum
  VALID_ROLES = %w[observer participant lead].freeze
  # a guest never leads a project
  GUEST_ROLES = %w[observer participant].freeze

  belongs_to :org
  belongs_to :project, inverse_of: :participants
  belongs_to :member, inverse_of: :participations

  enum :role, VALID_ROLES.index_with(&:itself), validate: { message: "%{value} is not a project role" }, scopes: false

  scope :leads, -> { where(role: "lead") }

  before_validation :set_org

  after_create :grant_pending_participation_request
  after_destroy :archive_guest_without_project, unless: :destroyed_by_association

  validates :member, uniqueness: { scope: :project_id } # mirrors the unique DB index
  validate :member_of_the_projects_org
  validate :guest_leads_no_project
  validates :role, presence: true

  private

  # project leads manage participants and see the org's members, guests must not
  def guest_leads_no_project
    errors.add(:role, :guest_lead) if member&.guest? && lead?
  end

  # a guest sees only their projects: without one they have no business in the org
  def archive_guest_without_project
    member.archive! if member.guest? && !member.participations.exists?
  end

  # added through the form or an invitation, the member asking to join is answered
  def grant_pending_participation_request
    ParticipationRequest.pending.where(project:, member:).update_all(status: "granted", decided_at: Time.current, updated_at: Time.current)
  end

  def member_of_the_projects_org
    errors.add(:member, :invalid) if member && project && member.org_id != project.org_id
  end

  def set_org
    self.org ||= project.org
  end
end
