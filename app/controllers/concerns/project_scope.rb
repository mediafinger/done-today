module ProjectScope
  extend ActiveSupport::Concern

  included do
    helper_method :current_project if respond_to? :helper_method
  end

  def switch_current_project(project_id)
    return unless current_member

    Current.project = current_member.projects.find(project_id)
  end

  private

  def current_project
    Current.project ||=
      switch_current_project(current_member.projects.first.id) if current_member && current_member.projects.count == 1
  end
end
