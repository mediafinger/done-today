module Orgs
  # A project's entries of one ISO week, newest day first, with each member's day
  #   total. Read-only like the tag page.
  #
  class WeeksController < AppOrgBaseController
    include ProjectEntries

    def show
      @week = monday

      if @week.nil?
        return redirect_to project_path(current_org, project, view: "weeks"),
          alert: t("controllers.unknown_week", week: params[:week])
      end

      @entries =
        readable_entries
          .where(days: { date: @week..(@week + 6.days) })
          .order(Day.arel_table[:date].desc, status: :desc, created_at: :asc)

      @totals = TimeSummary.day_totals(@entries)
    end

    private

    # the Monday of `2026-W39`, or nil
    def monday
      Date.strptime(params[:week], PeriodSummary::WEEK_PARAM)
    rescue Date::Error
      nil
    end
  end
end
