# This table stores :created, :updated and other events for records owned by orgs
#
# It has indices to allow for fast queries, using the get_ methods below
#   t.index ["event", "record_type", "org_id"]
#   t.index ["event", "record_type", "user_id"]
#   t.index ["org_id", "record_type", "record_id"]
# It does neither hold any DB or AR enforced associations to other tables or models
#   nor does it validate the data persisted.
#
# To become more useful an ID to a new "RecordHistoryChanges" table could be added
#   and more detailed information stored in this table. Given the amount of data, it
#   might be sane to remove all Changes older than 30.days or so.
#
class RecordHistory < ApplicationRecord
  validates :done_by_admin, inclusion: [true, false]
  validates :event, presence: true
  validates :record_changes, presence: true, unless: -> { record_changes.is_a?(Hash) } # it's a JSONB column, so {} is valid (but blank)
  validates :record_id, presence: true
  validates :record_type, presence: true
  validates :org_id, presence: true
  validates :user_id, presence: true

  class << self
    def get_history_for_org_record(org:, record:)
      where(org_id: org.id, record_type: record.class.name, record_id: record.id)
    end

    def get_history_for_org_events(org:, event:, klass:)
      where(org_id: org.id, event:, record_type: klass)
    end

    def get_history_for_user_events(user:, event:, klass:)
      where(user_id: user.id, event:, record_type: klass)
    end
  end

  def readonly?
    created_at.present?
  end
end
