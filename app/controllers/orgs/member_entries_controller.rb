module Orgs
  # One member's entries in a project, newest day first. Read-only like the tag page.
  #
  class MemberEntriesController < AppOrgBaseController
    include ProjectEntries

    before_action { authorize! project, to: :show? }

    def index
      @member = members.find(params[:member_id])
      @members = members.order(:name).pluck(:id)

      @entries =
        readable_entries
          .where(member: @member)
          .order(Day.arel_table[:date].desc, status: :desc, created_at: :asc)
    end

    private

    # the participants, and those removed from the project whose entries are still in it
    def members
      current_org.members.where(id: project.participants.select(:member_id))
        .or(current_org.members.where(id: project.entries.select(:member_id)))
    end
  end
end
