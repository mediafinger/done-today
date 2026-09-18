module Orgs
  class EntriesController < ApplicationController
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
      date # to initialize it
      @group_by = group_by
      @scroll_to = params[:scroll_to]
      @with_date = params[:date].blank?
      @with_member = params[:member_id].blank?
      @with_project = current_project.blank? || params[:project_id].present? # TODO: display always ?!
      # TODO: or handle only current_project in this controller and leave the rest for the projects_controller ?!

      if params[:member_id]
        @member = project.members.find(params[:member_id])
        @members = project.members.order(:name).pluck(:id, :name)
      end

      # TODO: ensure edit mode always uses current_project OR makes it obvious & switches to project!!!
      if mode == "edit"
        @day = days.find_by(date:) || days.build(org: current_org, date:)

        @entries =
          editable_entries(member: current_member, entries: @day.entries)
            .includes(:member, day: :project)
            .order(status: :desc, created_at: :asc)
      elsif mode == "read"
        date_days = days
        date_days = date_days.where(date:) if params[:date].present?

        @entries =
          current_org.entries
            .where(day: date_days)
            .includes(:member, day: :project)
            .order(status: :desc, created_at: :asc)

        @entries = @entries.where(member: @member) if @member
      end
    end

    # create_params[:date] is coming from a hidden form field and contains either
    #   the day's date or the date given in the URL.
    #   Therefore we need to find or create a day for the given date.
    #
    def create
      entry = Entry.new(
        org: current_org,
        member: current_member,
        day: current_project.days.find_or_create_by!(org: current_org, date: create_params[:date]),
        log: create_params[:log],
        status: create_params[:status] || "todo", # TODO
      )

      if entry.save
        redirect_to entries_path(date: entry.day.date, mode: "edit", scroll_to: "new-entry-field")
      else
        redirect_to entries_path(date: entry.day.date, mode: "edit"), alert: entry.errors.full_messages.to_sentence
      end
    end

    def update
      entry = current_project.entries.find(params[:id])

      # `key?`, not `present?`: a submitted-but-blank log has to reach the validations
      #   rather than being silently dropped
      entry.status = update_params[:status] if update_params.key?(:status)
      entry.log    = update_params[:log]    if update_params.key?(:log)

      if entry.save
        redirect_to entries_path(date: entry.day.date, mode: "edit") # TODO: scroll_to: "entry-id"
      else
        redirect_to entries_path(date: entry.day.date, mode: "edit"), alert: entry.errors.full_messages.to_sentence
      end
    end

    private

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

    def project
      @project ||=
        if params[:project_id]
          current_org.projects.find(params[:project_id])
        else
          current_project
        end

      raise ArgumentError, "no project given" if @project.blank?

      @project
    end

    def group_by
      return params[:group_by] if params[:group_by]
      return "date" if params[:date]
      return "member" if params[:member_id]
      return "project" if params[:project_id] # TODO: use slug

      "date" # a bare /entries shows today
    end

    def readable_entries(member:, entries:)
      participant(member:).readable_entries(relation: entries)
    end

    def editable_entries(member:, entries:)
      # TODO: ensure participant.owner can see who's entries they edit
      # @with_member = participant(member:).roles.include?("owner")

      participant(member:).editable_entries(relation: entries)
    end

    def participant(member:)
       @participant ||= member.participations.find_by(project:)
    end

    def create_params
      params.require(:entry).permit(:date, :log, :status)
    end

    def update_params
      params.require(:entry).permit(:log, :status)
    end
  end
end
