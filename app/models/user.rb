class User < ApplicationRecord
  has_secure_password

  has_many :memberships, class_name: "Member", inverse_of: :user, dependent: :destroy
  has_many :orgs, through: :memberships
  has_many :sessions, dependent: :destroy

  has_one_attached :profile_picture

  normalizes :email, with: ->(e) { e.strip.downcase }
  normalizes :name, with: ->(n) { n.strip }

  validates :email, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP, message: "%{value} is not a valid email format" }
  validates :name, presence: true, length: { in: 3..72 }
  validates :password, allow_nil: true, length: { in: 12..72 }, on: %i[create update reset_password]
  validates :password, not_pwned: { message: "might easily be guessed" }
  validates :password_digest, presence: true
end
