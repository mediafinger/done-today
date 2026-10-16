# An org owner invites an email address. The emailed link carries a signed token
#   that expires after EXPIRES_IN, and dies when the invitation is resent (sent_at)
#   or accepted (accepted_at). Nothing secret is stored.
#
#   Accepting creates the Member, see Users::InvitationsController.
#
class Invitation < ApplicationRecord
  EXPIRES_IN = 7.days

  class AlreadyAccepted < StandardError; end

  belongs_to :org
  belongs_to :invited_by, class_name: "Member", optional: true

  generates_token_for :acceptance, expires_in: EXPIRES_IN do
    [ sent_at, accepted_at ]
  end

  scope :pending, -> { where(accepted_at: nil) }

  normalizes :email, with: ->(e) { e.strip.downcase }
  normalizes :name, with: ->(n) { n.strip.presence }

  before_validation -> { self.sent_at ||= Time.current }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP, message: "%{value} is not a valid email format" }
  validates :email, uniqueness: { scope: :org_id, conditions: -> { pending } }, unless: :accepted? # mirrors the partial index
  validates :sent_at, presence: true
  validates :roles, presence: true, array_inclusion: {
    in: Member::VALID_ROLES, message: "%{rejected_values} not allowed, roles must be in #{Member::VALID_ROLES}"
  }
  validate :not_a_member_yet, unless: :accepted?

  def accepted?
    accepted_at.present?
  end

  def expired?
    sent_at < EXPIRES_IN.ago
  end

  # Returns the new member. The lock refuses a second accept of the same link.
  def accept!(user)
    with_lock do
      raise AlreadyAccepted if accepted?

      org.members.create!(user:, roles:).tap { update!(accepted_at: Time.current) }
    end
  end

  private

  def not_a_member_yet
    return unless org && org.members.active.joins(:user).exists?(users: { email: })

    errors.add(:base, :already_a_member, email:)
  end
end
