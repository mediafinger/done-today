module Users
  class DisplayModesController < ApplicationController
    def update
      if current_user.update(display_mode_params)
        redirect_back_or_to edit_user_path
      else
        redirect_back_or_to edit_user_path, alert: current_user.errors.full_messages.to_sentence
      end
    end

    private

    def display_mode_params
      params.expect(user: %i[display_mode])
    end
  end
end
