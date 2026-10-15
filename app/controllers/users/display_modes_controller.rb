module Users
  class DisplayModesController < ApplicationController
    def dark
      Current.display_mode = cookies[:display_mode] = "dark"

      redirect_back_or_to root_path
    end

    def light
      Current.display_mode = cookies[:display_mode] = "light"

      redirect_back_or_to root_path
    end

    def system
      cookies.delete(:display_mode)
      Current.display_mode = nil

      redirect_back_or_to root_path
    end
  end
end
