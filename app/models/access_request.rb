# An internal member asks to join a project they do not take part in. The project's
#   leads, or the org's managers and owners, grant it (which adds the member) or decline it.
#   Decided requests stay as a record, a declined member may ask again.
#
#   Who may ask and decide is decided in ProjectPolicy.
#
class AccessRequest < ApplicationRecord
  STATUSES = %w[pending granted declined].freeze

  belongs_to :org
  belongs_to :project, inverse_of: :access_requests
  belongs_to :member, inverse_of: :access_requests
  belongs_to :decided_by, class_name: "Member", optional: true

  enum :status, STATUSES.index_with(&:itself), validate: true

  # deactivated members wait, their requests count again when they are reactivated
  scope :awaiting, -> { pending.joins(:member).merge(Member.active) }

  normalizes :message, with: ->(m) { m.strip.presence }

  before_validation :set_org

  validates :status, presence: true
  validates :message, length: { maximum: 500 }
  validate :one_pending_request, if: :pending?
  validate :member_of_the_projects_org

  # the project's active leads, or the org's active managers and owners when it has none
  def recipients
    leads = project.members.active.merge(Participant.leads)

    leads.exists? ? leads : org.members.active.where(role: Member::MANAGING_ROLES)
  end

  # Returns the participant, unsaved with its errors when the role does not fit.
  def grant!(by:, role:)
    project.participants.new(member:, role:).tap do |participant|
      next unless participant.valid?

      transaction do
        decide!("granted", by)
        participant.save!
      end
    end
  end

  def decline!(by:)
    decide!("declined", by)
  end

  private

  def decide!(status, by)
    update!(status:, decided_by: by, decided_at: Time.current)
  end

  # mirrors the partial unique index
  def one_pending_request
    return unless project && member

    others = self.class.pending.where(project:, member:).where.not(id:)
    errors.add(:base, :already_requested, project: project.name) if others.exists?
  end

  def member_of_the_projects_org
    errors.add(:member, :invalid) if member && project && member.org_id != project.org_id
  end

  def set_org
    self.org ||= project&.org
  end
end
