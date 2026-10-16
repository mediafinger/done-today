# Every member has one org role:
#   guest - an external: participates in projects, sees only those, never leads one
#   member - an internal: can participate in projects (after invitation), sees all projects and members
#   manager - can manage members, projects and participants, can read all existing entries,
#             but neither gives nor takes the owner role
#   owner - all of the above, and can manage the organization and its owners
#
# What the roles allow is decided in app/policies.
#
# Members are never deleted while they have entries: deactivating one sets
#   `archived_at`, which takes their access to the org and keeps their history.
#   `unarchive!` gives the access back.
#
class Member < ApplicationRecord
  VALID_ROLES = %w[guest member manager owner].freeze
  INTERNAL_ROLES = %w[member manager owner].freeze
  MANAGING_ROLES = %w[manager owner].freeze

  belongs_to :org, inverse_of: :members
  belongs_to :user, inverse_of: :memberships

  # entries are history: archive the member instead (the DB FK refuses as well)
  has_many :entries, dependent: :restrict_with_exception
  # access grants, not history -- only reached for a member without entries
  has_many :participations, class_name: "Participant", inverse_of: :member, dependent: :destroy

  has_many :projects, through: :participations
  has_many :sent_invitations, class_name: "Invitation", foreign_key: :invited_by_id, inverse_of: :invited_by,
    dependent: :nullify
  # asking to join a project
  has_many :access_requests, inverse_of: :member, dependent: :destroy
  has_many :decided_access_requests, class_name: "AccessRequest", foreign_key: :decided_by_id, inverse_of: :decided_by,
    dependent: :nullify

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  enum :role, VALID_ROLES.index_with(&:itself), validate: { message: "%{value} is not an org role" }, scopes: false

  scope :owners, -> { where(role: "owner") }
  scope :internal, -> { where(role: INTERNAL_ROLES) }
  scope :guests, -> { where(role: "guest") }

  before_validation :set_user_name, on: :create

  validates :name, :role, presence: true
  validate :org_keeps_an_owner, on: :update
  validate :guest_with_a_project, on: :update, if: -> { will_save_change_to_role?(to: "guest") }

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current) unless archived?
  end

  def unarchive!
    update!(archived_at: nil)
  end

  def internal?
    INTERNAL_ROLES.include?(role)
  end

  def managing?
    MANAGING_ROLES.include?(role)
  end

  def active_owner?
    !archived? && owner?
  end

  private

  # Serialize concurrent changes with `org.with_lock`, or two owners can demote each other.
  def org_keeps_an_owner
    was_active_owner = attribute_in_database(:archived_at).nil? && attribute_in_database(:role) == "owner"
    return if !was_active_owner || active_owner?
    return if org.members.active.owners.where.not(id:).exists?

    errors.add(:base, :last_owner, org: org.name)
  end

  # a guest only sees their projects, so they need one, and they lead none
  def guest_with_a_project
    led = participations.leads.includes(:project).map { it.project.name }

    errors.add(:role, :guest_lead, projects: led.sort.to_sentence) if led.any?
    errors.add(:role, :guest_without_project) if participations.none?
  end

  def set_user_name
    self.name = user.name if name.blank?
  end
end
