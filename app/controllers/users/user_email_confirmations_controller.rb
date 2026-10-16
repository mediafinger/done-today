module Users
  # The link mailed to the new address. It works without a session: the token proves
  #   access to the address, the change itself was asked for with the current password.
  #
  class UserEmailConfirmationsController < ApplicationController
    # the emailed token decides
    skip_verify_authorized
    skip_verify_authorized_scoped

    allow_unauthenticated_access

    before_action :set_user

    layout -> { authenticated? ? "application" : "logged_out" }

    # a button, not the link: mail scanners open links
    def show
    end

    def update
      if @user.confirm_email_change
        redirect_to authenticated? ? edit_user_path : new_session_path, notice: "Your email is now #{@new_email}."
      else
        flash.now[:alert] = @user.errors.full_messages.to_sentence
        render :show, status: :unprocessable_content
      end
    end

    private

    def set_user
      @user = User.find_by_token_for(:email_confirmation, params[:token])
      return redirect_to new_session_path, alert: "That confirmation link is invalid or has expired." unless @user

      @new_email = @user.unconfirmed_email
    end
  end
end
