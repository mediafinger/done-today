# For the pages listing the entries of one project. `?project_id=` names any project
#   the member may read (404 otherwise), without it the current project is shown.
#
module ProjectEntries
  extend ActiveSupport::Concern

  included do
    before_action :require_project
  end

  private

  # nil rather than raising, `require_project` turns it into a redirect
  def project
    @project ||=
      if params[:project_id].present?
        ProjectPolicy.readable(current_member).find(params[:project_id])
      else
        current_project
      end
  end

  def readable_entries
    EntryPolicy.readable(current_member)
      .joins(:day)
      .where(days: { project_id: project.id })
      .includes(:member, day: :project)
  end
end
