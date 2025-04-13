module Users
  class DisplayModesController < ApplicationController
    def dark
      Current.display_mode = cookies[:display_mode] = "dark"

      redirect_to request.referrer
    end

    def light
      Current.display_mode = cookies[:display_mode] = "light"

      redirect_to request.referrer
    end

    def system
      cookies.delete(:display_mode)
      Current.display_mode = nil

      redirect_to request.referrer
    end
  end
end
