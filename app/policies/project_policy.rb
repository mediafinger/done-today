# Reading a project means reading all of its entries. An archived project stays
#   readable and exportable, nobody writes into it any more.
#
class ProjectPolicy < ApplicationPolicy
  READ_ROLES = %w[observer participant lead].freeze
  WRITE_ROLES = %w[participant lead].freeze

  # org managers and owners have to join a project to log time in it, and nobody invites guests to an archived one
  pre_check :allow_org_manager, except: %i[ create_entry? invite_guest? ]

  alias_rule :validate_times?, to: :show?
  alias_rule :export_csv?, :export_days_csv?, to: :export?
  # rename, archive, unarchive
  alias_rule :edit?, :update?, :archive?, :unarchive?, to: :manage?

  relation_scope do |relation|
    next relation.none unless active?
    next relation.where(org_id: member.org_id) if org_manager?

    relation.where(id: member.participations.includes_a_role_of(READ_ROLES).select(:project_id))
  end

  # internals know every project of the org, guests only theirs, reading still takes a participation
  relation_scope(:listable) do |relation|
    next relation.where(org_id: member.org_id) if internal?

    authorized_scope(relation)
  end

  # managers and owners of the org, leads of the project
  relation_scope(:manageable) do |relation|
    next relation.none unless active?
    next relation.where(org_id: member.org_id) if org_manager?

    relation.where(id: member.participations.includes_all_roles(%w[lead]).select(:project_id))
  end

  # a full export covers everybody's entries, so it takes managing the org or leading the project
  relation_scope(:exportable) do |relation|
    authorized_scope(relation, as: :manageable)
  end

  # ask with the Project class, org managers and owners only (pre-check)
  def create? = false

  def show?
    roles.intersect?(READ_ROLES)
  end

  def create_entry?
    !record.archived? && roles.intersect?(WRITE_ROLES)
  end

  def export?
    roles.include?("lead")
  end

  def manage?
    roles.include?("lead")
  end

  # send, resend and revoke the guest invitations of the project
  def invite_guest?
    !record.archived? && (org_manager? || roles.include?("lead"))
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
