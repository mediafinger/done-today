# Creates an org, or finds it by name, and makes OWNER_EMAIL its owner (rake done:org:create).
#   An existing account becomes an owner right away. A new email gets an owner invitation:
#   accounts are only created by accepting one.
#
class OrgSetup
  Result = Data.define(:org, :created, :member, :invitation)

  def self.call(name:, owner_email:, owner_name: nil)
    Org.transaction do
      org = Org.find_by(name:)
      created = org.nil?
      org ||= Org.create!(name:)

      if (user = User.find_by(email: owner_email))
        member = org.members.find_or_initialize_by(user:)
        member.update!(roles: member.roles | %w[member owner], archived_at: nil)

        Result.new(org:, created:, member:, invitation: nil)
      else
        invitation = org.invitations.pending.find_or_initialize_by(email: owner_email)
        invitation.update!(roles: %w[member owner], name: owner_name, sent_at: Time.current)

        Result.new(org:, created:, member: nil, invitation:)
      end
    end
  end
end
