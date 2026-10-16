# Reading a project means reading all of its entries. An archived project stays
#   readable and exportable, nobody writes into it any more.
#
class ProjectPolicy < ApplicationPolicy
  READ_ROLES = %w[observer participant lead].freeze
  WRITE_ROLES = %w[participant lead].freeze

  # org managers and owners have to join a project to log time in it, nobody invites guests to an archived one,
  #   and they add themselves rather than ask
  pre_check :allow_org_manager, except: %i[ create_entry? invite_guest? request_access? ]

  alias_rule :validate_times?, to: :show?
  # rename, archive, unarchive
  alias_rule :edit?, :update?, :archive?, :unarchive?, to: :manage?
  # a full export covers everybody's entries, the edit trail (RecordHistory) everybody's changes
  alias_rule :export?, :export_csv?, :export_days_csv?, :entry_history?, to: :manage?

  relation_scope do |relation|
    next relation.none unless active?
    next relation.where(org_id: member.org_id) if org_manager?

    relation.where(id: member.participations.where(role: READ_ROLES).select(:project_id))
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

    relation.where(id: member.participations.leads.select(:project_id))
  end

  # a full export covers everybody's entries, so it takes managing the org or leading the project
  relation_scope(:exportable) do |relation|
    authorized_scope(relation, as: :manageable)
  end

  # ask with the Project class, org managers and owners only (pre-check)
  def create? = false

  def show?
    READ_ROLES.include?(role)
  end

  def create_entry?
    !record.archived? && WRITE_ROLES.include?(role)
  end

  def manage?
    role == "lead"
  end

  # send, resend and revoke the guest invitations of the project
  def invite_guest?
    !record.archived? && allowed_to?(:manage?)
  end

  # members ask to join an active project they do not take part in, its leads grant it (manage?)
  def request_access?
    internal? && !org_manager? && !record.archived? && role.nil?
  end

  private

  def role
    project_role(record)
  end
end
