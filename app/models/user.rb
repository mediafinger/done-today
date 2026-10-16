# Changing the email sets `unconfirmed_email` first: the address only changes once the
#   link mailed to it is opened. The old address gets a link to cancel the change, or to
#   undo it within EMAIL_REVERT_EXPIRES_IN, see Users::EmailChangesMailer.
#
class User < ApplicationRecord
  DISPLAY_MODES = %w[system light dark].freeze
  # IANA identifiers of the zones Rails offers, e.g. "Europe/Berlin"
  TIME_ZONES = ActiveSupport::TimeZone.all.map { it.tzinfo.identifier }.uniq.freeze
  EMAIL_CONFIRMATION_EXPIRES_IN = 1.day
  EMAIL_REVERT_EXPIRES_IN = 7.days

  has_secure_password

  # where the user worked last, see LandingService
  belongs_to :last_org, class_name: "Org", optional: true
  belongs_to :last_project, class_name: "Project", optional: true

  # members carry the entries: archive them instead (the DB FK refuses as well)
  has_many :memberships, class_name: "Member", inverse_of: :user, dependent: :restrict_with_exception
  has_many :orgs, through: :memberships
  has_many :sessions, dependent: :destroy

  has_one_attached :profile_picture

  generates_token_for :email_confirmation, expires_in: EMAIL_CONFIRMATION_EXPIRES_IN do
    unconfirmed_email
  end

  normalizes :email, with: ->(e) { e.strip.downcase }
  normalizes :unconfirmed_email, with: ->(e) { e.strip.downcase.presence }
  normalizes :name, with: ->(n) { n.strip }

  validates :email, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP, message: "%{value} is not a valid email format" }
  validates :name, presence: true, length: { in: 3..72 }
  validates :password, allow_nil: true, length: { in: 10..72 }, on: %i[create update reset_password]
  validates :password, presence: true, on: :change_password
  validates :password, not_pwned: { message: "might easily be guessed" }, if:  :production_env
  validates :password_digest, presence: true
  validates :display_mode, inclusion: { in: DISPLAY_MODES }
  validates :time_zone, inclusion: { in: TIME_ZONES, message: "%{value} is not a known time zone" }
  validates :unconfirmed_email, allow_nil: true,
    format: { with: URI::MailTo::EMAIL_REGEXP, message: "%{value} is not a valid email format" }
  validate :unconfirmed_email_available, if: -> { unconfirmed_email_changed? && unconfirmed_email }

  # [user, from, to] of a valid link, nil otherwise
  def self.find_by_email_revert_token(token)
    id, from, to = email_revert_verifier.verified(token, purpose: :email_revert)
    user = find_by(id:) if id
    [ user, from, to ] if user
  end

  def self.email_revert_verifier
    Rails.application.message_verifier(:email_revert)
  end

  # value for <html data-theme>, nil lets Pico follow the OS setting
  def theme
    display_mode unless display_mode == "system"
  end

  def confirm_email_change
    update(email: unconfirmed_email, unconfirmed_email: nil)
  end

  # for the old address, carries both addresses: it still works after the change
  def email_revert_token(from: email, to: unconfirmed_email)
    self.class.email_revert_verifier.generate([ id, from, to ], purpose: :email_revert, expires_in: EMAIL_REVERT_EXPIRES_IN)
  end

  # :cancelled a pending change, :reverted a confirmed one (and signed out everywhere),
  #   nil when the link no longer matches the account
  def revert_email_change(from:, to:)
    if unconfirmed_email == to
      update!(unconfirmed_email: nil)
      :cancelled
    elsif email == to && update(email: from, unconfirmed_email: nil)
      sessions.delete_all
      :reverted
    end
  end

  def end_sessions_except(session)
    sessions.where.not(id: session.id).delete_all
  end

  # Opening an org keeps the project remembered in it, a project of another org is dropped.
  #   Skips validations: an invalid legacy record must not break opening a page.
  #
  def remember_last_visit!(org:, project: nil)
    project_id =
      if project then (project.id if project.org_id == org.id)
      elsif last_org_id == org.id then last_project_id
      end
    return if last_org_id == org.id && last_project_id == project_id

    update_columns(last_org_id: org.id, last_project_id: project_id) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  def unconfirmed_email_available
    if unconfirmed_email == email
      errors.add(:unconfirmed_email, :same_as_email)
    elsif User.where.not(id:).exists?(email: unconfirmed_email)
      errors.add(:unconfirmed_email, :taken)
    end
  end

  def production_env
    AppConf.production_env?
  end
end
