class Participant < ApplicationRecord
  VALID_ROLES = %w[participant observer owner].freeze

  belongs_to :org
  belongs_to :project, inverse_of: :participants
  belongs_to :member, inverse_of: :participations

  validates :roles, presence: true, array_inclusion: {
    in: VALID_ROLES, message: "%{rejected_values} not allowed, roles must be in #{VALID_ROLES}"
  }
end
