class SwitchOrgsController < ApplicationController
  # before_action :current_member

  # def index
  #   members = authorizing_scope!(current_user.memberships, with: UserMemberPolicy)
  #   current_user_orgs = members.map(&:org)

  #   render Views::SwitchCurrentOrgs::Index.new(current_user_orgs:)
  # end

  # def show
  #   org = current_user.orgs.find_by(id: params[:id])
  #   member = current_user.memberships.find_by(org:)

  #   authorize! member, with: UserMemberPolicy

  #   if current_org
  #     render Views::Orgs::Orgs::Show.new(org:, member:)
  #   else
  #     redirect_to switch_current_orgs_path, notice: "No org selected"
  #   end
  # end

  # def create
  #   members = authorized_scope(current_user.memberships, with: UserMemberPolicy)
  #   member = members.find_by!(org_id: current_org_params[:org_id])

  #   authorize! member, with: UserMemberPolicy

  #   switch_current_org(member.org_id)

  #   redirect_to dashboard_path, notice: "Org '#{current_org.name}' selected"
  # end

  # def destroy
  #   authorize! Current.session, with: ApplicationPolicy

  #   go_solo

  #   redirect_to root_path, notice: "No org selected, going solo"
  # end

  # GET /open/:slug_org/:slug_project
  #
  def switch_to
    org = Org.find_by!(slug: params[:slug_org])
    member = current_user.memberships.find_by(org:)
    project = org.projects.find_by(slug: params[:slug_project])
    participant = member.participations.find_by(project:)

    if member.present?
      switch_current_org(org.id)

      if project.present? && participant.present?
        switch_current_project(project.id)
        redirect_to project_path(project), notice: "Org '#{current_org.name}' with project '#{project.name}' selected"
      else
        redirect_to projects_path, notice: "Org '#{current_org.name}' selected"
      end
    else
      redirect_to root_path, alert: "You are not a member of this org"
    end
  end

  # private

  # def current_org_params
  #   params.expect(current_org: [ :org_id ])
  # end
end
