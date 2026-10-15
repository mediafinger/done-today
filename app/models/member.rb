# member - can participate in projects (after invitation)
# owner - can manage members, can manage organization,
#         can manage projects, can manage participants, can read all existing entries
#
# What the roles allow is decided in app/policies.
#
# Members are never deleted while they have entries: deactivating one sets
#   `archived_at`, which takes their access to the org and keeps their history.
#   `unarchive!` gives the access back.
#
class Member < ApplicationRecord
  VALID_ROLES = %w[member owner].freeze

  belongs_to :org, inverse_of: :members
  belongs_to :user, inverse_of: :memberships

  # entries are history: archive the member instead (the DB FK refuses as well)
  has_many :entries, dependent: :restrict_with_exception
  # access grants, not history -- only reached for a member without entries
  has_many :participations, class_name: "Participant", inverse_of: :member, dependent: :destroy

  has_many :projects, through: :participations

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  scope :includes_a_role_of, ->(roles) { roles ? where("roles && ARRAY[?]::text[]", roles) : all }
  scope :includes_all_roles, ->(roles) { roles ? where("roles @> ARRAY[?]::text[]", roles) : all }

  before_validation :set_user_name, on: :create

  validates :name, presence: true
  validates :roles, presence: true, array_inclusion: {
    in: VALID_ROLES, message: "%{rejected_values} not allowed, roles must be in #{VALID_ROLES}"
  }

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current) unless archived?
  end

  def unarchive!
    update!(archived_at: nil)
  end

  def add_role!(role)
    add_role(role).save!
  end

  def add_role(role)
    unless VALID_ROLES.include?(role.to_s)
      errors.add(:roles, "invalid role, must be in #{VALID_ROLES}")
      return self
    end

    roles << role.to_s
    roles.uniq!

    self
  end

  def delete_role!(role)
    delete_role(role).save!
  end

  def delete_role(role)
    self.roles = (roles - Array(role.to_s)).uniq
    self
  end

  private

  def set_user_name
    self.name = user.name if name.blank?
  end
end
