# Base class for the controllers of the pages below /:org_slug.
#
class AppOrgBaseController < ApplicationController
  before_action :set_current_org
end
