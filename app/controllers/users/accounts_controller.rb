module Users
  class AccountsController < ApplicationController
    before_action :set_sessions

    def show
      @user = current_user
    end

    def update
      @user = current_user
      @user.assign_attributes(profile_params.except(:password_challenge))
      # an email change needs the current password, "" fails the check just like a wrong one
      @user.password_challenge = profile_params[:password_challenge].to_s if @user.will_save_change_to_email?

      if @user.save
        redirect_to account_path, notice: "Account updated."
      else
        render_failure
      end
    end

    private

    def set_sessions
      @sessions = current_user.sessions.order(created_at: :desc)
    end

    def profile_params
      params.expect(user: %i[name email password_challenge])
    end

    def render_failure
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_content
    end
  end
end
