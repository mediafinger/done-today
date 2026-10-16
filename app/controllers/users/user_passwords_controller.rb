module Users
  class UserPasswordsController < ApplicationController
    # the signed-in user's own account
    skip_verify_authorized
    skip_verify_authorized_scoped

    before_action :set_user

    def edit
    end

    def update
      @user.assign_attributes(password_params)
      @user.password_challenge = password_params[:password_challenge].to_s

      if @user.save(context: %i[update change_password])
        # a changed password must lock out whoever else might be signed in
        @user.end_sessions_except(Current.session)
        redirect_to edit_user_path, notice: "Password changed. All other sessions were signed out."
      else
        flash.now[:alert] = @user.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_user
      @user = current_user
    end

    def password_params
      params.expect(user: %i[password password_confirmation password_challenge])
    end
  end
end
