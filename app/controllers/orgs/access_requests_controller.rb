module Orgs
  # Members ask to join a project they do not take part in, its leads get a mail.
  #   Those who manage the project (ProjectPolicy#manage?) grant or decline, as they add participants.
  #
  class AccessRequestsController < AppOrgBaseController
    # the requester cannot read the project yet, see #create
    before_action :set_current_project, except: :create
    before_action(except: :create) { authorize! current_project, to: :manage? }

    rate_limit to: 10, within: 1.hour, only: :create, by: -> { current_member.id },
      with: -> { redirect_to org_path(current_org), alert: t("controllers.access_requests.rate_limited") }

    # looked up among the projects listed to the member
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

    def grant
      participant = access_request.grant!(by: current_member, role: params.expect(access_request: [ :role ])[:role])

      if participant.persisted?
        redirect_to back_path, notice: t("controllers.participants.added", name: participant.member.name, role: participant.role)
      else
        redirect_to back_path, alert: participant.errors.full_messages.to_sentence
      end
    end

    def decline
      access_request.decline!(by: current_member)

      redirect_to back_path, notice: t("controllers.access_requests.declined", name: access_request.member.name)
    end

    private

    # a decided request, or one of a deactivated member, is a 404
    def access_request
      @access_request ||= current_project.access_requests.awaiting.find(params[:id])
    end

    def back_path
      edit_project_path(current_org, current_project)
    end
  end
end
