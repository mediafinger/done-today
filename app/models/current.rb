class Current < ActiveSupport::CurrentAttributes
  attribute :admin_flag
  attribute :ip_address
  attribute :member
  attribute :member_id
  attribute :module_name
  attribute :org
  attribute :org_id
  attribute :path
  attribute :request_id
  attribute :session
  attribute :user
  attribute :user_agent
  attribute :user_id

  # TODO: remove once CUSTOMIZED Authentication concern is included
  delegate :user, to: :session, allow_nil: true

  def user=(user)
    self.user_id = user&.id
    super
  end

  def org=(org)
    self.org_id = org&.id
    super
  end

  def member=(member)
    self.member_id = member&.id
    super
  end
end
