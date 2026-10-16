class HelpController < ApplicationController
  # public page, nothing to authorize
  skip_verify_authorized
  skip_verify_authorized_scoped

  allow_unauthenticated_access
  before_action :resume_session # signed-in users keep their nav

  def show
  end
end
