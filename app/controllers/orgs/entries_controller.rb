module Orgs
  # Writes and deletes entries in the project of the path, each with a RecordHistory.
  #   They are read and edited on the day, week, tag and member pages.
  #
  class EntriesController < AppOrgBaseController
    include ProjectEntries

    # the unlock toggle of the day page comes along as `unlocked`
    before_action :set_unlocked, only: %i[ create update destroy ]

    # create_params[:date] is coming from a hidden form field and contains either
    #   the day's date or the date given in the URL.
    #
    def create
      authorize! current_project, to: :create_entry?

      result = Entries::Create.call(
        project: current_project,
        member: current_member,
        date: create_params[:date],
        log: create_params[:log],
        status: create_params[:status],
        unlocked: @unlocked,
      )
      @entry = result.entry

      # on success the form starts over with a blank entry, on failure it keeps
      #   what was typed so the error can be corrected instead of retyped
      @new_entry = result.saved ? Entry.new(org: current_org, member: current_member, day: @entry.day) : @entry

      respond_to_save(result.saved, entry: @entry)
    end

    def update
      @entry = authorize! current_project.entries.find(params[:id])

      result = Entries::Update.call(entry: @entry, attributes: update_params, unlocked: @unlocked)

      respond_to_save(result.saved, entry: @entry)
    end

    # The day page asks before, when an entry's text was deleted. The day stays.
    def destroy
      @entry = authorize! current_project.entries.find(params[:id])

      result = Entries::Destroy.call(entry: @entry, unlocked: @unlocked)
      @entries_left = authorized_scope(Entry.all, as: :editable).exists?(day_id: @entry.day_id) if result.saved

      respond_to_save(result.saved, entry: @entry)
    end

    private

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
