module Orgs
  # Members ask to join a project they do not take part in, its leads get a mail.
  #   The project is looked up among those listed to the member: they cannot read it yet.
  #
  class AccessRequestsController < AppOrgBaseController
    rate_limit to: 10, within: 1.hour, only: :create, by: -> { current_member.id },
      with: -> { redirect_to org_path(current_org), alert: t("controllers.access_requests.rate_limited") }

    def create
      project = authorized_scope(current_org.projects, as: :listable).find_by!(slug: params[:project_slug])
      authorize! project, to: :request_access?

      access_request = project.access_requests.new(member: current_member, message: params.dig(:access_request, :message))

      if access_request.save
        access_request.recipients.each { AccessRequestsMailer.requested(access_request, it).deliver_later }

        redirect_to org_path(current_org), notice: t("controllers.access_requests.requested", project: project.name)
      else
        redirect_to org_path(current_org), alert: access_request.errors.full_messages.to_sentence
      end
    end
  end
end
