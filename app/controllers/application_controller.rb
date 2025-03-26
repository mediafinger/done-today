class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  def error_404
    render :error_404, status: :not_found
  end

  def home
    render :home, status: :ok
  end
end
