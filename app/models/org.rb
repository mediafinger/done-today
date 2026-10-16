class Org < ApplicationRecord
  include Sluggable

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

  validates :name, presence: true, uniqueness: true
  validates :slug, uniqueness: true

  private

  # /:org_slug looks orgs up without any scope, so their slugs are unique across all orgs
  def slug_scope
    Org.all
  end

  def reserved_path
    "/#{slug}"
  end
end
