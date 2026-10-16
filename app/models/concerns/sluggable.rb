# Derives the URL slug from the name once, on create: "Acme & Sons" -> "acme-sons".
#   A reserved slug is refused, never suffixed. A slug taken within `slug_scope`
#   gets the next free number: acme, acme-2, acme-3.
#
module Sluggable
  extend ActiveSupport::Concern

  # Orgs are the first path segment (/acme), projects the second (/acme/website).
  #   One list for both, so no slug is a page at one level and a project at another.
  #   spec/routing/reserved_slugs_spec.rb fails when a route or a file in public/ is missing here.
  RESERVED_SLUGS = [
    # pages
    *%w[datenschutz help impressum invitations members passwords projects session settings up user],
    # framework paths and files in public/ (error pages are covered by NUMBERED)
    *%w[assets cable favicon icon manifest rails robots service-worker],
    *%w[recede_historical_location refresh_historical_location resume_historical_location],
    # planned areas and pages
    *%w[admin api blog contact dev faq jobs site support],
    # former paths, so old bookmarks never open an org
    *%w[dark_mode days display_mode entries light_mode open orgs preferences sessions system_mode tags users weeks]
  ].freeze

  # 404, 500-x, 1st: error pages and status-like paths, while 2026-retro stays possible
  NUMBERED = /\A\d{1,3}(?!\d)/

  def self.reserved?(slug)
    RESERVED_SLUGS.include?(slug) || slug.to_s.match?(NUMBERED)
  end

  included do
    before_validation :set_slug, on: :create

    validate :name_gives_a_usable_slug, on: :create
    validates :slug, presence: true, exclusion: { in: RESERVED_SLUGS }, format: { without: NUMBERED }, on: :update
  end

  def to_param
    slug
  end

  private

  def set_slug
    base = name.to_s.parameterize
    return self.slug = base if base.blank? || Sluggable.reserved?(base)

    taken = slug_scope.where("slug = ? OR slug LIKE ?", base, "#{self.class.sanitize_sql_like(base)}-%").pluck(:slug)
    return self.slug = base if taken.exclude?(base)

    numbers = taken.filter_map { it[/\A#{Regexp.escape(base)}-(\d+)\z/, 1]&.to_i }
    self.slug = "#{base}-#{[ 1, *numbers ].max + 1}"
  end

  def name_gives_a_usable_slug
    if slug.blank?
      errors.add(:name, :no_slug)
    elsif slug.match?(NUMBERED)
      errors.add(:name, :numbered_slug)
    elsif Sluggable.reserved?(slug)
      errors.add(:name, :reserved_slug, slug:)
    end
  end
end
