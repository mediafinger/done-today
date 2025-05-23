# participant - can create new entries, can read existing entries, can edit their own entries
# observer - can read existing entries
# owner - can create new entries, can read existing entries, can edit all entries,
#         can manage project, can manage participants (as can org-owner)
#
class Participant < ApplicationRecord
  VALID_ROLES = %w[participant observer owner].freeze

  belongs_to :org
  belongs_to :project, inverse_of: :participants
  belongs_to :member, inverse_of: :participations

  scope :includes_a_role_of, ->(roles) { roles ? where("roles && ARRAY[?]::text[]", roles) : all }
  scope :includes_all_roles, ->(roles) { roles ? where("roles @> ARRAY[?]::text[]", roles) : all }

  before_validation :set_org

  validates :roles, presence: true, array_inclusion: {
    in: VALID_ROLES, message: "%{rejected_values} not allowed, roles must be in #{VALID_ROLES}"
  }

  def editable_entries(relation: nil)
    entries = project.entries
    entries = entries.where(id: relation) if relation.present?

    if roles.include?("owner")
      entries
    elsif roles.include?("participant")
      entries.where(member:)
    else
      entries.none
    end
  end

  def readable_entries(relation: nil)
    entries = project.entries
    entries = entries.where(id: relation) if relation.present?

    if roles.include?("owner") || roles.include?("participant") || roles.include?("observer")
      entries
    else
      entries.none
    end
  end

  private

  def set_org
    self.org ||= project.org
  end
end
