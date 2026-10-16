# Mission Control (/admin/mission_control_jobs) inherits from AdminController, so only admins get in.
#   Its controllers load lazily, after this ran.
MissionControl::Jobs.base_controller_class = "AdminController"
MissionControl::Jobs.http_basic_auth_enabled = false
