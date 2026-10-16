class Org < ApplicationRecord
  include Sluggable

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
end
