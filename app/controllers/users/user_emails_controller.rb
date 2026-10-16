module Users
  class UserEmailsController < ApplicationController
    # the signed-in user's own account
    skip_verify_authorized
    skip_verify_authorized_scoped

    before_action :set_user

    def edit
    end

    def update
      @user.email = email_params[:email]
      # "" fails the check just like a wrong password
      @user.password_challenge = email_params[:password_challenge].to_s

      if @user.save
        redirect_to edit_user_path, notice: "Email changed."
      else
        flash.now[:alert] = @user.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_user
      @user = current_user
    end

    def email_params
      params.expect(user: %i[email password_challenge])
    end
  end
end
