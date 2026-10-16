# Asks ActionPolicy (app/policies) on behalf of `current_member`.
#
#   Records the member cannot read are looked up through `authorized_scope` and end
#   in a 404. Records they can read but not change end here, in a 403.
#
module Authorization
  extend ActiveSupport::Concern

  included do
    authorize :member, through: :current_member

    # every action authorizes and scopes, or says why it does not need to
    verify_authorized
    verify_authorized_scoped

    rescue_from ActionPolicy::Unauthorized, with: :render_forbidden
  end

  private

  # The action already ran: in production a missed check is reported, not turned into a 500.
  def verify_authorized
    super
  rescue ActionPolicy::UnauthorizedAction => e
    report_missed_check(e)
  end

  def verify_authorized_scoped
    super
  rescue ActionPolicy::UnscopedAction => e
    report_missed_check(e)
  end

  def report_missed_check(error)
    raise error unless Rails.env.production?

    Rails.error.report(error)
  end

  def render_forbidden
    respond_to do |format|
      format.html { render "application/error_403", status: :forbidden }
      format.any { head :forbidden }
    end
  end
end
