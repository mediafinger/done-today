# The tag times report of a period (ReportPeriod) for a project or the whole org: TagTimes as HTML,
#   TagTimesExport with `.csv`. `?member_id=` narrows it down to one member.
#
module TagTimesReport
  extend ActiveSupport::Concern

  private

  # `entries` the report may sum up, `project` nil for the whole org
  def tag_times_report(entries, project: nil)
    @member = authorized_scope(current_org.members).find(params[:member_id]) if params[:member_id].present?
    @period = ReportPeriod.from_params(params, today: Time.zone.today)

    return redirect_to_current_period(project) if @period.nil?

    entries = entries.joins(:day).where(days: { date: @period.range })
    entries = entries.where(member: @member) if @member

    respond_to do |format|
      format.html do
        @tag_times = TagTimes.new(entries)

        render "orgs/tags/index"
      end
      format.csv do
        export = TagTimesExport.new(entries:, org: current_org, period: @period, project:, member: @member)

        send_data export.to_csv, filename: export.filename, type: "text/csv"
      end
    end
  end

  def redirect_to_current_period(project)
    kind = ReportPeriod.kind_in(params)
    path = project ? tags_path(current_org, project, member_id: @member&.id) : org_tags_path(current_org, member_id: @member&.id)

    redirect_to path, alert: t("controllers.unknown_#{kind}", kind => params[kind])
  end
end
