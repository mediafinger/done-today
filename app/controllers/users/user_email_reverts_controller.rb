module Users
  # The link mailed to the old address: cancels a pending change, or undoes a confirmed
  #   one and signs the account out everywhere. It works without a session.
  #
  class UserEmailRevertsController < ApplicationController
    # the emailed token decides
    skip_verify_authorized
    skip_verify_authorized_scoped

    allow_unauthenticated_access

    before_action :set_change

    layout -> { authenticated? ? "application" : "logged_out" }

    # a button, not the link: mail scanners open links
    def show
    end

    def update
      case @user.revert_email_change(from: @from, to: @to)
      when :cancelled
        redirect_to authenticated? ? edit_user_path : new_session_path, notice: "Cancelled the change to #{@to}."
      when :reverted
        cookies.delete(:session_id)
        redirect_to new_password_path, notice: "Restored #{@from} and signed out everywhere. Choose a new password if somebody else changed your email."
      else
        refuse_link
      end
    end

    private

    def set_change
      @user, @from, @to = User.find_by_email_revert_token(params[:token])
      return refuse_link unless @user && @to

      @pending = @user.unconfirmed_email == @to
      refuse_link unless @pending || @user.email == @to
    end

    def refuse_link
      redirect_to new_session_path, alert: "That link is invalid or has expired."
    end
  end
end
