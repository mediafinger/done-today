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
        @day =
          days.find_by(date: params[:date]) || days.build(org: current_org, date: params[:date] || Time.current.to_date)

        @entries =
          editable_entries(member: current_member, entries: @day.entries)
            .order(status: :desc, created_at: :asc)
      elsif mode == "read"
        date_days = days
        date_days = date_days.where(date: params[:date]) if params[:date]
        @entries = current_org.entries.where(day: date_days).order(status: :desc, created_at: :asc)
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

      entry.save!

      redirect_to entries_path(date: entry.day.date, mode: "edit")
    end

    def update
      entry = current_project.entries.find(params[:id])

      entry.status = update_params[:status]  if update_params[:status].present?
      entry.log    = update_params[:log]     if update_params[:log].present?

      entry.save!

      redirect_to entries_path(date: entry.day.date, mode: "edit")
    end

    private

    def mode
      @mode ||= params[:mode] || "read"

      raise ArgumentError, "invalid mode: #{@mode}" unless %w[read edit].include?(@mode)

      @mode
    end

    def date
      @date ||= Date.parse(params[:date]) rescue Time.current.to_date
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

      nil
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
