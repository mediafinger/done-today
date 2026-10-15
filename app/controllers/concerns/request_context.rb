module RequestContext
  extend ActiveSupport::Concern

  def self.included(base)
    base.send :before_action, :initialize_request_context if base.respond_to? :before_action
    # base.send :before_action, :set_sentry_context # uncomment when hosting and using Sentry
  end

  private

  def initialize_request_context
    # Current.user = current_user # set in Authentication concern
    # Current.org = current_org # set in OrgScope concern
    # Current.member = current_member # set in OrgScope concern
    # Current.project = current_project # set in ProjectScope concern

    Current.ip_address = request.remote_ip
    Current.module_name = self.class.module_parent_name
    Current.path = request.path
    Current.request_id = request.request_id # set via middleware gem Rack::RequestID and/or ActionDispatch::RequestId
    Current.user_agent = request.user_agent
  end

  # uncomment, extract to it's own module and include after all Current.attributes are set when hosting and using Sentry
  #
  # def set_sentry_context
  #   Sentry.set_user(id: Current.user&.id)
  #
  #   Sentry.configure_scope do |scope|
  #     scope.set_extras(
  #       request_id: Current.request_id
  #       params: request.filtered_parameters,
  #
  #       user_id: Current.user&.id
  #       org_id: Current.org&.id,
  #       member_id: Current.member&.id,
  #       member_roles: Current.member&.roles,
  #     )
  #   end
  # end
end
