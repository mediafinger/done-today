class RecordHistoryService
  class << self
    #
    # org and user are mandatory params, but stored as org_id and user_id only
    #
    def call(record:, org:, user:, event:, done_by_admin: false)
      #
      # TODO: instead of creating now, push to background job to retry errors
      #
      RecordHistory.create!(
        done_by_admin:,
        event:,
        record_changes: record.changes,
        record_type: record.class.name,
        record_id: record.id,
        org_id: org.id,
        user_id: user.id
      )
    end
  end
end
