module ApplicationHelper
  include Authentication # makes current_user available
  include OrgScope # makes current_org & current_member available
  include ProjectScope # makes current_project available
end
