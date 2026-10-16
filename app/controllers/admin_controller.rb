# Base of the admin area, and of the engines mounted in it (Mission Control).
#   AdminConstraint routes only admins here, AdminPolicy checks again.
#
class AdminController < ApplicationController
  # AdminPolicy asks for the user, the rest of the app for the member
  authorize :user, through: :current_user

  before_action { authorize! :admin, to: :access? }

  # nothing in the admin area belongs to an org, there is nothing to scope
  skip_verify_authorized_scoped
end
