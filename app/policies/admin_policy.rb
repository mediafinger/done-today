# The admin area is about the whole app, not an org: asked for the user, not a member.
class AdminPolicy < ActionPolicy::Base
  authorize :user, allow_nil: true

  def access?
    user&.admin? || false
  end
end
