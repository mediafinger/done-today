namespace :done do
  namespace :org do
    desc "Create an org and its first owner: NAME=Acme OWNER_EMAIL=ada@example.com [OWNER_NAME=Ada]"
    task create: :environment do
      name, email = ENV.values_at("NAME", "OWNER_EMAIL")
      abort "usage: rake done:org:create NAME=Acme OWNER_EMAIL=ada@example.com [OWNER_NAME=Ada]" if name.blank? || email.blank?

      result = OrgSetup.call(name:, owner_email: email, owner_name: ENV["OWNER_NAME"])
      org = result.org

      puts result.created ? "Created #{org.name} at /#{org.slug}" : "#{org.name} exists at /#{org.slug}"
      next puts("#{result.member.user.email} is an owner of #{org.name}") if result.member

      invitation = result.invitation
      url = Rails.application.routes.url_helpers.accept_invitation_url(
        invitation.generate_token_for(:acceptance), **Rails.application.config.action_mailer.default_url_options
      )
      puts "Invited #{invitation.email} as owner, the link is valid for #{Invitation::EXPIRES_IN.inspect}:", url

      begin
        InvitationsMailer.invite(invitation).deliver_now
      rescue StandardError => e
        warn "Could not mail the link (#{e.class}: #{e.message}), send it yourself."
      end
    rescue ActiveRecord::RecordInvalid => e
      abort e.message
    end
  end
end
