class Member < ApplicationRecord
  VALID_ROLES = %w[member owner].freeze

  belongs_to :org, inverse_of: :members
  belongs_to :user, inverse_of: :memberships

  has_many :entries, dependent: :destroy
  has_many :participations, class_name: "Participant", inverse_of: :member, dependent: :destroy

  has_many :projects, through: :participations

  validates :roles, presence: true, array_inclusion: {
    in: VALID_ROLES, message: "%{rejected_values} not allowed, roles must be in #{VALID_ROLES}"
  }
end
