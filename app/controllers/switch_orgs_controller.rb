class SwitchOrgsController < ApplicationController
  # GET /open/:slug_org/:slug_project
  #
  # Looks the org up through the user's memberships, so an unknown org and someone
  #   else's org get the same answer.
  #
  def switch_to
    member = current_user.memberships.joins(:org).find_by(org: { slug: params[:slug_org] })

    return redirect_to root_path, alert: "You are not a member of this org" if member.nil?

    switch_current_org(member.org_id)

    project = member.projects.find_by(slug: params[:slug_project])

    if project.present?
      switch_current_project(project.id)
      redirect_to project_path(project.slug), notice: "Org '#{current_org.name}' with project '#{project.name}' selected"
    else
      redirect_to projects_path, notice: "Org '#{current_org.name}' selected"
    end
  end
end
