module Users
  # The emailed invitation link. A new email address chooses a name and a password,
  #   becomes a member and is signed in. The link never sets the password of an
  #   existing account.
  #
  class InvitationsController < ApplicationController
    allow_unauthenticated_access

    rate_limit to: 10, within: 3.minutes, only: :update,
      with: -> { redirect_to accept_invitation_path(params[:token]), alert: "Try again later." }

    rescue_from Invitation::AlreadyAccepted, with: :refuse_link

    before_action :set_invitation
    before_action :refuse_another_account

    layout -> { authenticated? ? "application" : "logged_out" }

    def show
      return render(:existing_account) if invited_user

      @user = User.new(email: @invitation.email, name: @invitation.name)
    end

    def update
      return render(:existing_account) if invited_user

      @user = User.new(email: @invitation.email, **params.expect(user: %i[ name password password_confirmation ]))

      if sign_up
        start_new_session_for(@user)
        redirect_to org_path(@invitation.org), notice: t("controllers.invitations.welcome", org: @invitation.org.name)
      else
        render :show, status: :unprocessable_content
      end
    end

    private

    def set_invitation
      @invitation = Invitation.includes(:org).find_by_token_for(:acceptance, params[:token])

      refuse_link unless @invitation
    end

    def refuse_link
      redirect_to new_session_path, alert: t("controllers.invitations.invalid")
    end

    def refuse_another_account
      render :another_account, status: :forbidden if authenticated? && current_user != invited_user
    end

    def invited_user
      @invited_user ||= User.find_by(email: @invitation.email)
    end

    # a second accept of the same link raises, and takes the new user back with it
    def sign_up
      Invitation.transaction { @user.save && @invitation.accept!(@user) }
    end
  end
end
