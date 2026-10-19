module Orgs
  # The tags of a project: the time each one took in a month, and every entry
  #   carrying one. Read-only: a tag spans many days, and a day is only ever
  #   edited on its own page.
  #
  class TagsController < AppOrgBaseController
    include ProjectEntries

    before_action { authorize! project, to: :show? }

    # Each tag's time in a month, from the durations on its lines (EntryLog#timed_tag).
    def index
      @month = month

      if @month.nil?
        return redirect_to tags_path(current_org, project), alert: t("controllers.unknown_month", month: params[:month])
      end

      @tag_times = TagTimes.new(
        authorized_scope(Entry.all).joins(:day).where(days: { project_id: project.id, date: @month.all_month })
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

    private

    # `?month=2026-10`, the user's current month without one, nil when unreadable
    def month
      return Time.zone.today.beginning_of_month if params[:month].blank?

      Date.strptime(params[:month].to_s, "%Y-%m")
    rescue Date::Error
      nil
    end
  end
end
