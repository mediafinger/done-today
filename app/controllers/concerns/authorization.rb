# Asks ActionPolicy (app/policies) on behalf of `current_member`.
#
#   Records the member cannot read are looked up through `authorized_scope` and end
#   in a 404. Records they can read but not change end here, in a 403.
#
module Authorization
  extend ActiveSupport::Concern

  included do
    authorize :member, through: :current_member

    rescue_from ActionPolicy::Unauthorized, with: :render_forbidden
  end

  private

  def render_forbidden
    respond_to do |format|
      format.html { render "application/error_403", status: :forbidden }
      format.any { head :forbidden }
    end
  end
end
