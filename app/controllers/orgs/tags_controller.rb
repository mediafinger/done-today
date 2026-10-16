module Orgs
  # Every entry of a project carrying one tag, newest first. Read-only: a tag spans
  #   many days, and a day is only ever edited on its own page.
  #
  class TagsController < AppOrgBaseController
    include ProjectEntries

    before_action { authorize! project, to: :show? }

    def show
      # EntryLog stores tags downcased, so `Handover` and `%23handover` find `#handover`
      @tag = params[:tag].delete_prefix("#").downcase

      @entries =
        readable_entries
          .where("entries.tags @> ARRAY[?]::text[]", @tag)
          .order(Day.arel_table[:date].desc, created_at: :desc)
    end
  end
end
