class RecordHistoryService
  # attributes that must never be written into the history diff
  FILTERED_KEYS = %w[password password_digest credentials].freeze

  class MissingContextError < StandardError; end

  class << self
    #
    # TODO: instead of creating now, push to background job to retry errors
    #
    def call(record:, event:, org: Current.org, user: Current.user, done_by_admin: Current.admin_flag.present?)
      raise MissingContextError, "no org in scope, pass `org:` explicitly" if org.blank?
      raise MissingContextError, "no user in scope, pass `user:` explicitly" if user.blank?

      RecordHistory.create!(
        done_by_admin:,
        event:,
        org:,
        record_changes: diff_for(record, event),
        record_id: record.id,
        record_type: record.class.name,
        user_id: user.id
      )
    end

    private

    # after a successful save the diff lives in `previous_changes`; a :deleted event
    #   has no diff to report, only that it happened
    #
    def diff_for(record, event)
      return {} if event.to_sym == :deleted

      changes = record.previous_changes.presence || record.changes

      changes.except(*FILTERED_KEYS)
    end
  end
end
