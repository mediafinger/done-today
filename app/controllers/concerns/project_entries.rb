# For the pages below /:org_slug/:project_slug, which list or write that project's entries.
#
module ProjectEntries
  extend ActiveSupport::Concern

  included do
    before_action :set_current_project
  end

  private

  def project
    @project ||= current_project
  end

  def readable_entries
    EntryPolicy.readable(current_member)
      .joins(:day)
      .where(days: { project_id: project.id })
      .includes(:member, day: :project)
  end
end
