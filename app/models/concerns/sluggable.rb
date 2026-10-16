# Derives the URL slug from the name once, on create: "Acme & Sons" -> "acme-sons".
#   A slug the routes use (RESERVED_SLUGS) is refused, never suffixed. A slug taken
#   within `slug_scope` gets the next free number: acme, acme-2, acme-3.
#
module Sluggable
  extend ActiveSupport::Concern

  included do
    before_validation :set_slug, on: :create

    validate :name_gives_a_usable_slug, on: :create
    validates :slug, presence: true, exclusion: { in: ->(record) { record.class::RESERVED_SLUGS } }, on: :update
  end

  def to_param
    slug
  end

  private

  def set_slug
    base = name.to_s.parameterize
    return self.slug = base if base.blank? || self.class::RESERVED_SLUGS.include?(base)

    taken = slug_scope.where("slug = ? OR slug LIKE ?", base, "#{self.class.sanitize_sql_like(base)}-%").pluck(:slug)
    return self.slug = base if taken.exclude?(base)

    numbers = taken.filter_map { it[/\A#{Regexp.escape(base)}-(\d+)\z/, 1]&.to_i }
    self.slug = "#{base}-#{[ 1, *numbers ].max + 1}"
  end

  def name_gives_a_usable_slug
    if slug.blank?
      errors.add(:name, :no_slug)
    elsif self.class::RESERVED_SLUGS.include?(slug)
      errors.add(:name, :reserved_slug, path: reserved_path)
    end
  end
end
