module Orgs
  # Writes entries into the project of the path, each write with a RecordHistory.
  #   They are read and edited on the day, week, tag and member pages.
  #
  class EntriesController < AppOrgBaseController
    include ProjectEntries

    # the unlock toggle of the day page comes along as `unlocked`
    before_action :set_unlocked, only: %i[ create update ]

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
        status: create_params[:status] || "todo",
      )

      # a failing history takes the new day along
      saved = open_day?(@entry) && Entry.transaction { day.save! && @entry.create_with_history }

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

      respond_to_save(open_day?(@entry) && @entry.update_with_history, entry: @entry)
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
          path = edit_day_path(current_org, current_project, entry.day.date, unlocked: (@unlocked || nil))

          if saved
            redirect_to path
          else
            redirect_to path, alert: entry.errors.full_messages.to_sentence
          end
        end
      end
    end

    def create_params
      params.require(:entry).permit(:date, :log, :status)
    end

    def update_params
      params.require(:entry).permit(:log, :status)
    end
  end
end
