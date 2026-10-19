module Orgs
  # One day of a project. `show` reads everybody's entries, `edit` is where the own
  #   entries are written (through EntriesController#create and #update).
  #
  class DaysController < AppOrgBaseController
    include ProjectEntries

    before_action { authorize! project, to: :show? }

    before_action :set_date

    def show
      @entries = readable_entries.where(days: { date: @date }).order(status: :desc, created_at: :asc)
      @edited_ids = allowed_to?(:entry_history?, project) ? edited_ids(@entries) : Set.new
    end

    # When no day for the date exists yet, a new one is initialized, so the user can
    #   start typing a log immediately.
    #
    def edit
      # The unlock toggle lives in the URL, so it covers every entry of the day at once
      #   and is gone again as soon as the user navigates away.
      @unlocked = params[:unlocked].present?

      @day = project.days.find_by(date: @date) || project.days.build(org: current_org, date: @date)
      @new_entry = Entry.new(org: current_org, member: current_member, day: @day)

      # observers, org managers and owners who do not participate read the day instead
      writable = @writable = allowed_to?(:create_entry?, project)

      # a past day is read-only until it is unlocked on purpose
      @unlockable = writable && @date.past?
      @locked = !writable || (@unlockable && !@unlocked)

      @entries =
        if @day.persisted?
          entries = writable ? authorized_scope(Entry.all, as: :editable).where(day: @day) : @day.entries
          entries.includes(:member, day: :project).order(status: :desc, created_at: :asc)
        else
          @day.entries
        end

      @validatable = writable && @entries.any?
      validate_day if @validatable
    end

    private

    def edited_ids(entries)
      RecordHistory.for_org_events(org: current_org, event: "updated", klass: Entry)
        .where(record_id: entries.map(&:id)).distinct.pluck(:record_id).to_set
    end

    # the route only takes 2026-10-15, this refuses 2026-02-31
    def set_date
      @date = Date.iso8601(params[:date])
    rescue Date::Error
      raise ActionController::RoutingError, "No day #{params[:date]}"
    end

    # Checks what this member logged here today -- the entries of other participants
    #   are theirs to correct. Issues are always worth showing; the all-clear only
    #   answers the button, as a day nobody asked about does not need praising.
    #
    def validate_day
      own_entries = @day.entries.where(member: current_member).includes(:member, day: :project).to_a

      @asked_to_validate = params[:validate].present?
      @issues = TimeValidation.new(own_entries, times_required: project.times_required?).issues
      @validated_minutes = TimeSummary.new(own_entries).total_minutes
    end
  end
end
