# member - can participate in projects (after invitation)
# owner - can manage members, can manage organization,
#         can manage projects, can manage participants, can read all existing entries
#
class Member < ApplicationRecord
  VALID_ROLES = %w[member owner].freeze

  belongs_to :org, inverse_of: :members
  belongs_to :user, inverse_of: :memberships

  has_many :entries, dependent: :destroy
  has_many :participations, class_name: "Participant", inverse_of: :member, dependent: :destroy

  has_many :projects, through: :participations

  scope :includes_a_role_of, ->(roles) { roles ? where("roles && ARRAY[?]::text[]", roles) : all }
  scope :includes_all_roles, ->(roles) { roles ? where("roles @> ARRAY[?]::text[]", roles) : all }

  before_validation :set_user_name, on: :create

  validates :name, presence: true
  validates :roles, presence: true, array_inclusion: {
    in: VALID_ROLES, message: "%{rejected_values} not allowed, roles must be in #{VALID_ROLES}"
  }

  # not the projects are editable by the member, but they can create new entries and edit their own entries
  #
  def editable_projects(relation: nil)
    projects = org.projects
    projects = projects.where(id: relation) if relation.present?

    if roles.include?("owner") || roles.include?("member")
      editorship = participations.includes_a_role_of(%w[owner participant])
      projects = projects.where(id: editorship.pluck(:project_id))
    else
      projects.none
    end
  end

  def readable_projects(relation: nil)
    projects = org.projects
    projects = projects.where(id: relation) if relation.present?

    if roles.include?("owner")
      projects
    elsif roles.include?("member")
      projects = projects.where(id: projects)
    else
      projects.none
    end
  end

  # TODO: probably unnecessary method, use the one on participant, as we should always have a project available
  #
  # def editable_entries(relation: nil)
  #   entries = org.entries
  #   entries = entries.where(id: relation) if relation.present?

  #   # .where(member: self) # TODO: unless project.owner or member.owner

  #   # two query version - easy to read, simple queries
  #   #
  #   # days = org.days.where(project: projects)
  #   # entries.where(day: days)

  #   # # alternative joins version - hard to read, complex query - with unclear performance
  #   #
  #   #   entries = entries
  #   #               .joins(day: :project)
  #   #               .joins("INNER JOIN participants ON participants.project_id = projects.id")
  #   #               .where(participants: { member_id: id })
  #   #               .distinct
  # end

  def readable_entries(relation: nil)
    entries = org.entries
    entries = entries.where(id: relation) if relation.present?

    if roles.include?("owner")
      entries
    elsif roles.include?("member")
      days = org.days.where(project: projects) # all participants can read all entries of their projects
      entries.where(day: days)
    else
      entries.none
    end
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
