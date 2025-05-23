module ProjectScope
  extend ActiveSupport::Concern

  included do
    helper_method :current_project if respond_to? :helper_method
  end

  def switch_current_project(project_id)
    return unless current_member

    project = current_member.projects.find(project_id)
    refresh_current_project_in_session(project:)

    Current.project
  end

  private

  def refresh_current_project_in_session(project:)
    Current.session.update!(project:)

    Current.project = project
  end

  def current_project
    Current.project ||=
      if Current.session&.project && current_member&.projects&.exists?(id: Current.session.project)
        Current.session.project
      end # else nil
  end
end
