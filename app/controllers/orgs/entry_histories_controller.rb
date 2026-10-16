module Orgs
  # The edit trail of one entry (RecordHistory), for the leads of its project and the managers and owners of its org.
  #
  class EntryHistoriesController < AppOrgBaseController
    include ProjectEntries

    def show
      @entry = authorize! readable_entries.find(params[:entry_id]), to: :history?
      @histories = RecordHistory.for_org_record(org: current_org, record: @entry).order(:created_at)

      # archived members included, they made the changes all the same
      @actors = current_org.members.where(user_id: @histories.map(&:user_id)).index_by { it.user_id.to_s }
    end
  end
end
