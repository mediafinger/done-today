# Routes /admin only for the session of an admin (config/routes.rb), everyone else
#   gets what an unknown path answers: a 404, the sign-in page when not signed in.
#
class AdminConstraint
  def self.matches?(request)
    session_id = request.cookie_jar.signed[:session_id]
    return false unless session_id

    Session.includes(:user).find_by(id: session_id)&.user&.admin? || false
  end
end
