module Orgs
  # The tags of a project: the time each one took in a week, month or year, and every entry
  #   carrying one. Read-only: a tag spans many days, and a day is only ever
  #   edited on its own page.
  #
  class TagsController < AppOrgBaseController
    include ProjectEntries

    before_action { authorize! project, to: :show? }

    # Each tag's time in a period (ReportPeriod), from the durations on its lines (EntryLog#timed_tag).
    def index
      @period = ReportPeriod.from_params(params, today: Time.zone.today)

      if @period.nil?
        kind = ReportPeriod.kind_in(params)

        return redirect_to tags_path(current_org, project), alert: t("controllers.unknown_#{kind}", kind => params[kind])
      end

      @tag_times = TagTimes.new(
        authorized_scope(Entry.all).joins(:day).where(days: { project_id: project.id, date: @period.range })
      )
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
