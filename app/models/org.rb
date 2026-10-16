class Org < ApplicationRecord
  # The slug is the first segment of every org URL (/acme/website/days/2026-10-15),
  #   config/routes.rb skips these words when matching an org. spec/routing/reserved_slugs_spec.rb
  #   fails when a route or a file in public/ is missing here.
  RESERVED_SLUGS = [
    # pages
    *%w[datenschutz help impressum invitations passwords session settings up user],
    # framework paths and files in public/
    *%w[400 404 406-unsupported-browser 422 500 503 assets cable favicon icon manifest rails robots service-worker],
    *%w[recede_historical_location refresh_historical_location resume_historical_location],
    # planned areas
    *%w[admin api dev jobs],
    # former paths, so old bookmarks never open an org
    *%w[dark_mode days display_mode entries light_mode members open orgs preferences projects sessions system_mode tags
        users weeks]
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
