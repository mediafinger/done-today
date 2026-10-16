module Users
  class UserSessionsController < ApplicationController
    # the signed-in user's own account
    skip_verify_authorized
    skip_verify_authorized_scoped

    def index
      @sessions = current_user.sessions.order(created_at: :desc)
    end

    def destroy
      device_session = current_user.sessions.find(params[:id])

      if device_session == Current.session
        terminate_session
        redirect_to new_session_path
      else
        device_session.destroy!
        redirect_to user_sessions_path, notice: "Session signed out."
      end
    end

    def destroy_others
      count = current_user.end_sessions_except(Current.session)

      redirect_to user_sessions_path, notice: "Signed out of #{helpers.pluralize(count, 'other session')}."
    end
  end
end
