module Users
  # Asks for a new email: it only changes once the link mailed to the new address is
  #   opened, see UserEmailConfirmationsController. The old address can cancel or undo.
  #
  class UserEmailsController < ApplicationController
    # the signed-in user's own account
    skip_verify_authorized
    skip_verify_authorized_scoped

    rate_limit to: 10, within: 1.hour, only: :update, by: -> { current_user.id },
      with: -> { redirect_to edit_user_email_path, alert: "Too many email changes, try again later." }

    before_action :set_user

    def edit
    end

    def update
      @user.unconfirmed_email = email_params[:unconfirmed_email]
      # "" fails the check just like a wrong password
      @user.password_challenge = email_params[:password_challenge].to_s

      if @user.save
        Users::EmailChangesMailer.confirm(@user).deliver_later
        Users::EmailChangesMailer.requested(@user, @user.email, @user.unconfirmed_email).deliver_later

        redirect_to edit_user_path, notice: "Open the link we mailed to #{@user.unconfirmed_email} to confirm it."
      else
        flash.now[:alert] = @user.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @user.update!(unconfirmed_email: nil)

      redirect_to edit_user_email_path, notice: "Cancelled the email change."
    end

    private

    def set_user
      @user = current_user
    end

    def email_params
      params.expect(user: %i[unconfirmed_email password_challenge])
    end
  end
end
