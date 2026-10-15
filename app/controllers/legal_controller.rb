class LegalController < ApplicationController
  # public pages, nothing to authorize
  skip_verify_authorized
  skip_verify_authorized_scoped

  skip_before_action :require_authentication
  before_action :resume_session # signed-in users keep their nav

  def imprint
  end

  def privacy
  end
end
