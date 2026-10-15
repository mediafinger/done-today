module Orgs
  # One member's entries in a project, newest day first. Read-only like the tag page.
  #
  class MemberEntriesController < AppOrgBaseController
    include ProjectEntries

    def index
      @member = project.members.find(params[:member_id])
      @members = project.members.order(:name).pluck(:id)

      @entries =
        readable_entries
          .where(member: @member)
          .order(Day.arel_table[:date].desc, status: :desc, created_at: :asc)
    end
  end
end
