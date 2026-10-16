module Users
  class TimeZonesController < ApplicationController
    # a setting of the signed-in user's own
    skip_verify_authorized
    skip_verify_authorized_scoped

    def update
      if current_user.update(time_zone_params)
        redirect_to edit_user_path, notice: "Time zone updated."
      else
        redirect_to edit_user_path, alert: current_user.errors.full_messages.to_sentence
      end
    end

    private

    def time_zone_params
      params.expect(user: %i[time_zone])
    end
  end
end
