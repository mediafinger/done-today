# An internal member asks to join a project, its leads grant or decline.
#
class CreateAccessRequests < ActiveRecord::Migration[8.1]
  def change
    create_enum :access_request_status, %w[pending granted declined]

    create_table :access_requests, id: :uuid do |t|
      t.references :org, type: :uuid, null: false, foreign_key: true
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.references :member, type: :uuid, null: false, foreign_key: true
      t.text :message
      t.enum :status, enum_type: :access_request_status, default: "pending", null: false
      t.references :decided_by, type: :uuid, foreign_key: { to_table: :members }
      t.datetime :decided_at
      t.timestamps
    end

    add_index :access_requests, %i[project_id member_id], unique: true, where: "status = 'pending'",
      name: "index_access_requests_on_project_id_and_member_id_pending"
  end
end
