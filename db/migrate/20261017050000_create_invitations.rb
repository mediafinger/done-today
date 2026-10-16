# An org owner invites an email address into the org. The emailed link carries a
#   signed, expiring token (Invitation.generates_token_for), so no secret is stored.
#   One pending invitation per org and email; accepted ones stay as a record.
#
class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations, id: :uuid do |t|
      t.references :org, type: :uuid, null: false, foreign_key: true
      t.references :invited_by, type: :uuid, foreign_key: { to_table: :members }
      t.string :email, null: false
      t.string :name
      t.text :roles, array: true, null: false, default: %w[member]
      t.datetime :sent_at, null: false
      t.datetime :accepted_at
      t.timestamps
    end

    add_index :invitations, %i[org_id email], unique: true, where: "accepted_at IS NULL",
      name: "index_invitations_on_org_id_and_email_pending"
  end
end
