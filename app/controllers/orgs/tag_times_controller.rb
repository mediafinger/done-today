module Orgs
  # The tag times of all of the org's projects, archived ones and archived members included:
  #   the project report (TagsController#index) summed across projects. Org managers and owners only.
  #
  class TagTimesController < AppOrgBaseController
    before_action { authorize! current_org, to: :tag_times? }

    # `?member_id=` narrows it down to one member
    def index
      entries = authorized_scope(current_org.entries)
      @member = authorized_scope(current_org.members).find(params[:member_id]) if params[:member_id].present?
      @period = ReportPeriod.from_params(params, today: Time.zone.today)

      if @period.nil?
        kind = ReportPeriod.kind_in(params)

        return redirect_to org_tags_path(current_org, member_id: @member&.id), alert: t("controllers.unknown_#{kind}", kind => params[kind])
      end

      entries = entries.joins(:day).where(days: { date: @period.range })
      entries = entries.where(member: @member) if @member

      @tag_times = TagTimes.new(entries)

      render "orgs/tags/index"
    end
  end
end
