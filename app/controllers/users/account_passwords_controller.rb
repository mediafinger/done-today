module Users
  class AccountPasswordsController < AccountsController
    def update
      @user = current_user
      @user.assign_attributes(password_params)
      @user.password_challenge = password_params[:password_challenge].to_s

      if @user.save(context: %i[update change_password])
        # a changed password must lock out whoever else might be signed in
        @user.end_sessions_except(Current.session)
        redirect_to account_path, notice: "Password changed. All other sessions were signed out."
      else
        render_failure
      end
    end

    private

    def password_params
      params.expect(user: %i[password password_confirmation password_challenge])
    end
  end
end
