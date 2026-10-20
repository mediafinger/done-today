# Access to the MCP server: one personal access token, or one user's authorization of
#   an OAuth app (#109). The grants name orgs or projects; the user's roles cap them on
#   every call, so access ends as soon as a membership or participation does.
#   Connections are revoked, never deleted: the history keeps pointing at them.
#
class Connection < ApplicationRecord
  # a token's use is noted at most this often
  USE_INTERVAL = 1.minute
  # the expiries offered for a personal access token, there is none without
  PERSONAL_EXPIRY_DAYS = [ 7, 30, 90, 365 ].freeze


  belongs_to :user, inverse_of: :connections
  belongs_to :oauth_application, class_name: "Doorkeeper::Application", optional: true

  has_many :grants, class_name: "ConnectionGrant", inverse_of: :connection, dependent: :delete_all
  has_many :access_tokens, class_name: "Doorkeeper::AccessToken", dependent: :delete_all
  has_many :access_grants, class_name: "Doorkeeper::AccessGrant", dependent: :delete_all

  scope :active, -> { where(revoked_at: nil) }
  scope :personal, -> { where(oauth_application_id: nil) }

  validates :name, presence: true

  # the active connection of a bearer secret, nil for an unknown, expired or revoked one
  def self.authenticate(secret)
    token = Doorkeeper::AccessToken.by_token(secret)
    return unless token&.accessible?

    active.find_by(id: token.connection_id)&.tap(&:used!)
  end

  # :write, :read or nil: the strongest grant covering the project, capped by the user's
  #   participation in it right now
  #
  def access_for(project)
    return if revoked?

    granted = grants.covering(project).pluck(:access)
    capped(granted.include?("write") ? "write" : granted.first, project)
  end

  # what `access` gives in the project right now: reading takes a participation, writing
  #   a role that may log in an active project (ProjectPolicy#create_entry?)
  #
  def capped(access, project)
    return if access.nil?

    member = user.memberships.active.find_by(org_id: project.org_id)
    return unless ProjectPolicy::READ_ROLES.include?(member&.participations&.find_by(project:)&.role)

    access == "write" && ProjectPolicy.new(project, member:).apply(:create_entry?) ? :write : :read
  end

  # the secret, only known now
  def create_access_token!(expires_in:)
    access_tokens.create!(resource_owner_id: user_id, application: oauth_application, expires_in: expires_in.to_i).plaintext_token
  end

  # of a relation, e.g. a user's connections: revokes them all with their tokens
  def self.revoke_all!
    now = Time.current

    transaction do
      Doorkeeper::AccessToken.where(connection_id: active.select(:id), revoked_at: nil).update_all(revoked_at: now)
      active.update_all(revoked_at: now, updated_at: now)
    end
  end

  def revoke!
    transaction do
      update!(revoked_at: Time.current)
      access_tokens.where(revoked_at: nil).update_all(revoked_at: Time.current)
    end
  end

  def revoked?
    revoked_at.present?
  end

  def used!
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < USE_INTERVAL.ago
  end
end
