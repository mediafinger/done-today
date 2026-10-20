# An org (all its projects, also ones joined later) or one project of it, read or write.
#
class ConnectionGrant < ApplicationRecord
  ACCESS = %w[read write].freeze

  belongs_to :connection, inverse_of: :grants
  belongs_to :org
  belongs_to :project, optional: true

  validates :access, inclusion: { in: ACCESS }
  validates :project, uniqueness: { scope: :connection_id }, if: :project_id # mirrors the unique DB indexes
  validates :org, uniqueness: { scope: :connection_id, conditions: -> { where(project_id: nil) } }, unless: :project_id
  validate :project_of_the_org

  scope :covering, ->(project) { where(org_id: project.org_id, project_id: [ nil, project.id ]) }

  # :write, :read or nil: what the grant gives right now, in the best of the projects it covers
  def effective_access
    projects = project ? [ project ] : org.projects.where(id: Participant.where(member: connection.user.memberships).select(:project_id))

    projects.filter_map { connection.capped(access, it) }.max
  end

  private

  def project_of_the_org
    errors.add(:project, :invalid) if project && project.org_id != org_id
  end
end
