module Orgs
  # Org and project owners add active members of the org to a project, change their
  #   role and remove them. Removing takes the access, the entries stay.
  #
  class ParticipantsController < AppOrgBaseController
    before_action :set_current_project
    before_action { authorize!(current_project, :manage?) }

    def create
      # a deactivated member or one of another org is a 404, the form does not offer them
      member = current_org.members.active.find(participant_params[:member_id])
      participant = current_project.participants.new(member:, roles: [ participant_params[:role] ])

      respond(participant.save, :added, participant)
    end

    def update
      respond(participant.update(roles: [ participant_params[:role] ]), :updated, participant)
    end

    def destroy
      participant.destroy!

      redirect_to after_change_path, notice: t("controllers.participants.removed", name: participant.member.name)
    end

    private

    def participant
      @participant ||= current_project.participants.find(params[:id])
    end

    def participant_params
      params.expect(participant: %i[ member_id role ])
    end

    def respond(saved, done, participant)
      if saved
        redirect_to after_change_path,
          notice: t("controllers.participants.#{done}", name: participant.member.name, role: participant.role)
      else
        redirect_to edit_project_path(current_org, current_project), alert: participant.errors.full_messages.to_sentence
      end
    end

    # a project owner who stepped down or removed themselves cannot manage the project any more
    def after_change_path
      return edit_project_path(current_org, current_project) if policy(current_project).manage?
      return project_path(current_org, current_project) if policy(current_project).show?

      org_path(current_org)
    end
  end
end
