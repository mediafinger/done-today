module Orgs
  # The tag times of all of the org's projects, archived ones and archived members included:
  #   the project report (TagsController#index) summed across projects. Org managers and owners only.
  #   The CSV has a line per tag, member and project.
  #
  class TagTimesController < AppOrgBaseController
    include TagTimesReport

    before_action { authorize! current_org, to: :tag_times? }

    def index
      tag_times_report(authorized_scope(current_org.entries))
    end
  end
end
