# This table stores :created, :updated and other events for records owned by orgs
#
# It has indices to allow for fast queries, using the scopes below
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
# NOTE: the column is `record_changes`, not `changes` -- `changes` is ActiveModel::Dirty's
#   method, so Rails would never define an attribute method for a column of that name.
#
class RecordHistory < ApplicationRecord
  belongs_to :org

  scope :for_org_record, ->(org:, record:) { where(org:, record_type: record.class.name, record_id: record.id) }
  scope :for_org_events, ->(org:, event:, klass:) { where(org:, event:, record_type: klass.name) }
  scope :for_user_events, ->(user:, event:, klass:) { where(user_id: user.id, event:, record_type: klass.name) }

  # `record_changes` is NOT NULL and defaults to {}, and an empty diff is a legitimate
  #   value (e.g. a :deleted event), so it deliberately has no presence validation --
  #   see the ignore entry in .active_record_doctor.rb
  #
  validates :done_by_admin, inclusion: [ true, false ]
  validates :event, presence: true
  validates :record_type, presence: true
  validates :record_id, presence: true
  validates :user_id, presence: true

  def readonly?
    persisted?
  end
end
