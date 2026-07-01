class Org < ApplicationRecord
  has_many :entries, dependent: :destroy
  has_many :days, dependent: :destroy
  has_many :integrations, dependent: :destroy
  has_many :members, inverse_of: :org, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :record_histories, dependent: :destroy

  has_many :users, through: :members

  before_create :set_slug

  validates :name, presence: true, uniqueness: true

  private

  # TODO:
  # Catch raise conditions issue, by catching the potential DB exception for a duplicate slug and handle it with a retry
  # The exists? → create sequence has a TOCTOU (time-of-check, time-of-use) race.
  # Two concurrent requests could check, both find the slug available, and one will fail on the unique DB index.
  # The DB constraint catches it, but the exception is unhandled.

  def set_slug
    new_slug = name.parameterize

    new_slug = "#{new_slug}-#{rand(99)}" while Org.exists?(slug: new_slug)

    self.slug = new_slug
  end
end
