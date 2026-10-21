module TokenAuth
  # Hourly (config/recurring.yml): deletes OAuth apps that registered but nobody authorized
  #   within a day, and revokes connected apps unused for 90 days (#109).
  #
  class CleanupJob < ApplicationJob
    UNAUTHORIZED_FOR = 24.hours
    UNUSED_FOR = 90.days

    def perform
      Doorkeeper::Application.where(created_at: ...UNAUTHORIZED_FOR.ago)
        .where.not(id: Connection.where.not(oauth_application_id: nil).select(:oauth_application_id))
        .delete_all

      Connection.active.where.not(oauth_application_id: nil)
        .where("COALESCE(last_used_at, created_at) < ?", UNUSED_FOR.ago)
        .find_each(&:revoke!)
    end
  end
end
