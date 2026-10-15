module Users
  class OtherSessionsController < ApplicationController
    def destroy
      count = current_user.end_sessions_except(Current.session)

      redirect_to account_path, notice: "Signed out of #{helpers.pluralize(count, 'other session')}."
    end
  end
end
