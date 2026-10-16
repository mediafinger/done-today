# An org manager or owner invites an email address. The emailed link carries a signed token
#   that expires after EXPIRES_IN, and dies when the invitation is resent (sent_at)
#   or accepted (accepted_at). Nothing secret is stored.
#
#   A guest is invited to one project, by an org manager or owner, or the project's lead.
#
#   Accepting creates or reactivates the Member, see Users::InvitationsController.
#
class Invitation < ApplicationRecord
  EXPIRES_IN = 7.days

  class AlreadyAccepted < StandardError; end

  belongs_to :org
  belongs_to :invited_by, class_name: "Member", optional: true
  # guests only
  belongs_to :project, optional: true

  generates_token_for :acceptance, expires_in: EXPIRES_IN do
    [ sent_at, accepted_at ]
  end

  enum :role, Member::VALID_ROLES.index_with(&:itself), validate: { message: "%{value} is not an org role" },
    scopes: false

  scope :pending, -> { where(accepted_at: nil) }

  normalizes :email, with: ->(e) { e.strip.downcase }
  normalizes :name, with: ->(n) { n.strip.presence }

  before_validation -> { self.sent_at ||= Time.current }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP, message: "%{value} is not a valid email format" }
  validates :email, uniqueness: { scope: :org_id, conditions: -> { pending } }, unless: :accepted? # mirrors the partial index
  validates :sent_at, :role, presence: true
  validates :project, :project_role, presence: true, if: :guest?
  validates :project, :project_role, absence: true, unless: :guest?
  validates :project_role, inclusion: { in: Participant::GUEST_ROLES }, allow_nil: true
  validate :project_of_the_org, if: :project
  validate :not_a_member_yet, unless: :accepted?

  def accepted?
    accepted_at.present?
  end

  def expired?
    sent_at < EXPIRES_IN.ago
  end

  # accepting reactivates them with the invited role, which takes their owner role
  def to_deactivated_owner?
    org.members.archived.owners.joins(:user).exists?(users: { email: })
  end

  # Returns the member: a new one, the user's archived one reactivated with the invited
  #   role (one row per org and user), or their active one left as it is. A guest
  #   invitation also adds the project, so an active member only gains that.
  #   The lock refuses a second accept of the same link.
  def accept!(user)
    raise ArgumentError, "the invitation is for #{email}" unless user.email == email

    with_lock do
      raise AlreadyAccepted if accepted?

      member = org.members.find_or_initialize_by(user:)
      # a guest needs their project before the role changes
      join_project(member) if member.persisted?
      member.update!(role:, archived_at: nil) unless member.persisted? && !member.archived?
      join_project(member)
      update!(accepted_at: Time.current)

      member
    end
  end

  private

  def join_project(member)
    member.participations.find_or_create_by!(project:) { it.role = project_role } if project
  end

  def project_of_the_org
    errors.add(:project, :invalid) if project.org_id != org_id || project.archived?
  end

  # a guest invitation can add a project to somebody already in the org
  def not_a_member_yet
    return unless org

    active = org.members.active.joins(:user).where(users: { email: })

    if project
      errors.add(:base, :already_participates, email:, project: project.name) if active.joins(:participations).exists?(participations: { project_id: project.id })
    elsif active.exists?
      errors.add(:base, :already_a_member, email:)
    end
  end
end
