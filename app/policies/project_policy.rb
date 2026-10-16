# Reading a project means reading all of its entries. An archived project stays
#   readable and exportable, nobody writes into it any more.
#
class ProjectPolicy < ApplicationPolicy
  READ_ROLES = %w[observer participant owner].freeze
  WRITE_ROLES = %w[participant owner].freeze

  # org owners have to join a project to log time in it
  pre_check :allow_org_owner, except: :create_entry?

  alias_rule :validate_times?, to: :show?
  alias_rule :export_csv?, :export_days_csv?, to: :export?
  # rename, archive, unarchive
  alias_rule :edit?, :update?, :archive?, :unarchive?, to: :manage?

  relation_scope do |relation|
    next relation.none unless active?
    next relation.where(org_id: member.org_id) if org_owner?

    relation.where(id: member.participations.includes_a_role_of(READ_ROLES).select(:project_id))
  end

  # owners of the org or of the project
  relation_scope(:manageable) do |relation|
    next relation.none unless active?
    next relation.where(org_id: member.org_id) if org_owner?

    relation.where(id: member.participations.includes_all_roles(%w[owner]).select(:project_id))
  end

  # a full export covers everybody's entries, so it takes ownership of the org or the project
  relation_scope(:exportable) do |relation|
    authorized_scope(relation, as: :manageable)
  end

  # ask with the Project class, org owners only (pre-check)
  def create? = false

  def show?
    roles.intersect?(READ_ROLES)
  end

  def create_entry?
    !record.archived? && roles.intersect?(WRITE_ROLES)
  end

  def export?
    roles.include?("owner")
  end

  def manage?
    roles.include?("owner")
  end

  # who changed which entry when (RecordHistory)
  def entry_history?
    manage?
  end

  private

  def roles
    project_roles(record)
  end
end
