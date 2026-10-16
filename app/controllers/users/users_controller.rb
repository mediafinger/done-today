module Users
  class UsersController < ApplicationController
    # the signed-in user's own account
    skip_verify_authorized
    skip_verify_authorized_scoped

    before_action :set_user

    def edit
    end

    def update
      if @user.update(user_params)
        redirect_to edit_user_path, notice: "Name updated."
      else
        flash.now[:alert] = @user.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_user
      @user = current_user
    end

    def user_params
      params.expect(user: %i[name])
    end
  end
end
