class User < ApplicationRecord
  DISPLAY_MODES = %w[system light dark].freeze

  has_secure_password

  # members carry the entries: archive them instead (the DB FK refuses as well)
  has_many :memberships, class_name: "Member", inverse_of: :user, dependent: :restrict_with_exception
  has_many :orgs, through: :memberships
  has_many :sessions, dependent: :destroy

  has_one_attached :profile_picture

  normalizes :email, with: ->(e) { e.strip.downcase }
  normalizes :name, with: ->(n) { n.strip }

  validates :email, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP, message: "%{value} is not a valid email format" }
  validates :name, presence: true, length: { in: 3..72 }
  validates :password, allow_nil: true, length: { in: 10..72 }, on: %i[create update reset_password]
  validates :password, presence: true, on: :change_password
  validates :password, not_pwned: { message: "might easily be guessed" }, if:  :production_env
  validates :password_digest, presence: true
  validates :display_mode, inclusion: { in: DISPLAY_MODES }

  # value for <html data-theme>, nil lets Pico follow the OS setting
  def theme
    display_mode unless display_mode == "system"
  end

  def end_sessions_except(session)
    sessions.where.not(id: session.id).delete_all
  end

  private

  def production_env
    AppConf.production_env?
  end
end
