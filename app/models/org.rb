class Org < ApplicationRecord
  # The slug is the first segment of every org URL (/acme/website/days/2026-10-15),
  #   so it must not be a top-level path, present or planned. config/routes.rb skips
  #   these words when matching an org.
  RESERVED_SLUGS = %w[
    404 422 500 admin api assets cable dark_mode datenschutz days display_mode entries favicon help icon impressum
    invitations jobs light_mode manifest members open orgs passwords preferences projects rails
    recede_historical_location refresh_historical_location resume_historical_location robots service-worker session
    sessions settings system_mode tags up user users weeks
  ].freeze

  has_many :entries, dependent: :destroy
  has_many :days, dependent: :destroy
  has_many :invitations, dependent: :destroy # before members, it references the inviting member
  has_many :access_requests, dependent: :destroy # before members, it references the deciding member
  has_many :members, inverse_of: :org, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :record_histories, dependent: :delete_all # read-only, `destroy` would raise

  has_many :users, through: :members

  before_create :set_slug

  validates :name, presence: true, uniqueness: true
  validates :slug, exclusion: { in: RESERVED_SLUGS }

  def to_param
    slug
  end

  private

  def set_slug
    new_slug = name.parameterize

    new_slug = "#{new_slug}-#{rand(99)}" while RESERVED_SLUGS.include?(new_slug) || Org.exists?(slug: new_slug)

    self.slug = new_slug
  end
end
