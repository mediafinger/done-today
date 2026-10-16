module Users
  # A changed email is confirmed through the new address, the old one can cancel or undo it.
  class EmailChangesMailer < ApplicationMailer
    def confirm(user)
      @user = user
      @url = user_email_confirmation_url(user.generate_token_for(:email_confirmation))

      mail subject: "Confirm your new email", to: user.unconfirmed_email
    end

    # the addresses of the moment of the request, the job may run after the confirmation
    def requested(user, from, to)
      @to = to
      @url = user_email_revert_url(user.email_revert_token(from:, to:))

      mail subject: "Your email is about to change", to: from
    end
  end
end
