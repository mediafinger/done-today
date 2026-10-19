module Orgs
  # The tags of a project: the time each one took in a week, month or year, and every entry
  #   carrying one. Read-only: a tag spans many days, and a day is only ever
  #   edited on its own page.
  #
  class TagsController < AppOrgBaseController
    include ProjectEntries
    include TagTimesReport

    before_action { authorize! project, to: :show? }

    # Each tag's time in a period, from the durations on its lines (EntryLog#timed_tag), see TagTimesReport
    def index
      tag_times_report(authorized_scope(Entry.all).joins(:day).where(days: { project_id: project.id }), project:)
    end

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
