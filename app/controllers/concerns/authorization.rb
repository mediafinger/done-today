# Asks the record's policy (app/policies) on behalf of `current_member`.
#
#   Records the member cannot read are looked up through a policy scope and end
#   in a 404. Records they can read but not change end here, in a 403.
#
module Authorization
  extend ActiveSupport::Concern

  included do
    rescue_from ApplicationPolicy::NotAuthorizedError, with: :render_forbidden

    helper_method :policy if respond_to? :helper_method
  end

  private

  def policy(record)
    "#{record.class.name}Policy".constantize.new(current_member, record)
  end

  def authorize!(record, query)
    policy(record).authorize!(query)
  end

  def render_forbidden
    respond_to do |format|
      format.html { render "application/error_403", status: :forbidden }
      format.any { head :forbidden }
    end
  end
end
