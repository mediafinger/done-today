module Orgs
  # The tags of a project: the time each one took in a week, month or year, and every entry
  #   carrying one. Read-only: a tag spans many days, and a day is only ever
  #   edited on its own page.
  #
  class TagsController < AppOrgBaseController
    include ProjectEntries

    before_action { authorize! project, to: :show? }

    # Each tag's time in a period (ReportPeriod), from the durations on its lines (EntryLog#timed_tag).
    #   `?member_id=` narrows it down to one member. As CSV with `.csv` (TagTimesExport).
    def index
      @member = current_org.members.find(params[:member_id]) if params[:member_id].present?
      @period = ReportPeriod.from_params(params, today: Time.zone.today)

      if @period.nil?
        kind = ReportPeriod.kind_in(params)

        return redirect_to tags_path(current_org, project, member_id: @member&.id), alert: t("controllers.unknown_#{kind}", kind => params[kind])
      end

      entries = authorized_scope(Entry.all).joins(:day).where(days: { project_id: project.id, date: @period.range })
      entries = entries.where(member: @member) if @member

      respond_to do |format|
        format.html { @tag_times = TagTimes.new(entries) }
        format.csv do
          export = TagTimesExport.new(entries:, org: current_org, period: @period, project:, member: @member)

          send_data export.to_csv, filename: export.filename, type: "text/csv"
        end
      end
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
