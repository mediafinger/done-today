module Orgs
  class EntriesController < AppOrgBaseController
    # The unlock toggle lives in the URL, so it covers every entry of the day at once
    #   and is gone again as soon as the user navigates away.
    #
    before_action :set_unlocked
    before_action :require_project

    # when no day for the selected date exists yet, we initialize a new day,
    #   so the user can start typing a log immediately
    #
    # TODO: make the entries#index action the central point of the app
    #       * filter always by current_organization
    #       * filter optionally by date
    #       * filter optionally by project (if not given, restrict non-owners to participations)
    #       * filter optionally by member
    #       * filter optionally by status
    #       * group by date, project, status, member - enable to change order (and display of columns)
    #       * order("days.date desc", "days.project_id asc", "entries.status desc", "entries.member_id asc", "entries.created_at asc")
    #       * editable form or read-only view
    #
    # TODO: cleanup, extract, simplify!
    #
    # Ensure there is always 1 defined project, either current_project or @project from project_id!
    #
    def index
      # the old URLs may be bookmarked
      if params[:tag].present?
        return redirect_to tag_path(params[:tag], project_id: params[:project_id].presence), status: :moved_permanently
      end
      if params[:week].present?
        return redirect_to week_path(params[:week], project_id: params[:project_id].presence), status: :moved_permanently
      end
      if params[:member_id].present?
        return redirect_to member_entries_path(params[:member_id], project_id: params[:project_id].presence),
          status: :moved_permanently
      end
      # the project page lists the same entries, by day
      if params[:project_id].present? && params[:date].blank? && params[:mode] != "edit"
        return redirect_to project_path(project.slug), status: :moved_permanently
      end

      date # to initialize it
      @group_by = group_by
      @with_date = params[:date].blank?
      @with_project = current_project.blank? || params[:project_id].present? # TODO: display always ?!

      # TODO: ensure edit mode always uses current_project OR makes it obvious & switches to project!!!
      if mode == "edit"
        @day = days.find_by(date:) || days.build(org: current_org, date:)
        @new_entry = Entry.new(org: current_org, member: current_member, day: @day)

        # observers, and org owners who do not participate, read the day instead
        writable = policy(project).create_entry?

        # a past day is read-only until it is unlocked on purpose -- see #unlocked?
        @unlockable = writable && date.past?
        @locked = !writable || (@unlockable && !@unlocked)

        @entries =
          if @day.persisted?
            entries = writable ? EntryPolicy.editable(current_member).where(day: @day) : @day.entries
            entries.includes(:member, day: :project).order(status: :desc, created_at: :asc)
          else
            @day.entries
          end

        @validatable = writable && @entries.any?
        validate_day if @validatable

      elsif mode == "read"
        date_days = days
        date_days = date_days.where(date:) if params[:date].present?

        # start@ / end@ only add up within a single day
        @with_time_summary = @group_by == "date" && params[:date].present?

        @entries = EntryPolicy.readable(current_member).where(day: date_days).includes(:member, day: :project)
        @entries = @entries.order(status: :desc, created_at: :asc)
      end
    end

    # create_params[:date] is coming from a hidden form field and contains either
    #   the day's date or the date given in the URL.
    #   Therefore we need to find or create a day for the given date.
    #
    def create
      authorize!(current_project, :create_entry?)

      day = current_project.days.find_or_initialize_by(org: current_org, date: create_params[:date])

      @entry = Entry.new(
        org: current_org,
        member: current_member,
        day:,
        log: create_params[:log],
        status: create_params[:status] || "todo", # TODO
      )

      saved = open_day?(@entry) && day.save! && @entry.save

      # on success the form starts over with a blank entry, on failure it keeps
      #   what was typed so the error can be corrected instead of retyped
      @new_entry = saved ? Entry.new(org: current_org, member: current_member, day: @entry.day) : @entry

      respond_to_save(saved, entry: @entry)
    end

    def update
      @entry = authorize!(current_project.entries.find(params[:id]), :update?)

      # `key?`, not `present?`: a submitted-but-blank log has to reach the validations
      #   rather than being silently dropped
      @entry.status = update_params[:status] if update_params.key?(:status)
      @entry.log    = update_params[:log]    if update_params.key?(:log)

      respond_to_save(open_day?(@entry) && @entry.save, entry: @entry)
    end

    private

    # The lock on past days guards against changing them in passing. Whoever may
    #   write can lift it, by sending `unlocked` along like the unlocked page does.
    #
    def open_day?(entry)
      return true unless entry.day.date&.past? && !@unlocked

      entry.errors.add(:base, t("controllers.day_locked", date: entry.day.date.iso8601))
      false
    end

    # Checks what this member logged here today -- the entries of other participants
    #   are theirs to correct. Issues are always worth showing; the all-clear only
    #   answers the button, as a day nobody asked about does not need praising.
    #
    def validate_day
      own_entries = @day.entries.where(member: current_member).includes(:member, day: :project).to_a

      @asked_to_validate = params[:validate].present?
      @issues = TimeValidation.new(own_entries).issues
      @validated_minutes = TimeSummary.new(own_entries).total_minutes
    end

    def set_unlocked
      @unlocked = params[:unlocked].present?
    end

    # Saving happens on every blur now, so a full-page redirect per field exit would
    #   jump the page and throw the caret away. The Turbo Stream swaps just the entry
    #   that changed; the redirect stays as the no-JS fallback.
    #
    def respond_to_save(saved, entry:)
      respond_to do |format|
        format.turbo_stream { render status: saved ? :ok : :unprocessable_content }
        format.html do
          path = entries_path(date: entry.day.date, mode: "edit", unlocked: (@unlocked || nil))

          if saved
            redirect_to path
          else
            redirect_to path, alert: entry.errors.full_messages.to_sentence
          end
        end
      end
    end

    def mode
      @mode ||= params[:mode] || "read"

      raise ArgumentError, "invalid mode: #{@mode}" unless %w[read edit].include?(@mode)

      @mode
    end

    # the parsed date is the single source of truth -- the raw param used to be read
    #   again further down, so an unparseable date silently produced an empty day
    #   instead of falling back to today
    #
    def date
      @date ||=
        begin
          params[:date].present? ? Date.parse(params[:date]) : Time.zone.today
        rescue Date::Error
          Time.zone.today
        end
    end

    def days
      @days ||= current_org.days.where(project:)
    end

    # Returns nil rather than raising: `require_project` turns "no project" into a
    #   redirect, and an ArgumentError here would just be a 500 on the way there.
    #
    def project
      @project ||=
        if params[:project_id].present?
          ProjectPolicy.readable(current_member).find(params[:project_id])
        else
          current_project
        end
    end

    def group_by
      "date"
    end

    def create_params
      params.require(:entry).permit(:date, :log, :status)
    end

    def update_params
      params.require(:entry).permit(:log, :status)
    end
  end
end
