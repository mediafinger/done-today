class CreateDoneTodaySchema < ActiveRecord::Migration[8.0]
  def change
    enable_extension "pgcrypto" # Enable UUID extension

    create_enum :entry_status, %w[todo doing done]

    create_table :orgs, id: :uuid do |t|
      t.string :name, null: false

      t.timestamps

      t.index :name, unique: true
    end

    create_table :users, id: :uuid do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      t.text :bio
      t.boolean :admin, default: false
      t.timestamps

      t.index :email, unique: true
    end

    create_table :members, id: :uuid do |t|
      t.references :org, null: false, foreign_key: true, type: :uuid, index: false
      t.references :user, null: false, foreign_key: true, type: :uuid

      t.text "roles", default: %w[member], null: false, array: true
      t.datetime :send_reminder_at, default: "17:00"
      t.timestamps

      t.index [:org_id, :user_id], unique: true
    end

    create_table :projects, id: :uuid do |t|
      t.references :org, null: false, foreign_key: true, type: :uuid, index: false

      t.string :name, null: false
      t.timestamps

      t.index [:org_id, :name], unique: true
    end

    create_table :participants, id: :uuid do |t|
      t.references :org, null: false, foreign_key: true, type: :uuid
      t.references :project, null: false, foreign_key: true, type: :uuid, index: false
      t.references :member, null: false, foreign_key: true, type: :uuid

      t.text "roles", default: %w[participant], null: false, array: true
      t.timestamps

      t.index [:project_id, :member_id], unique: true
    end

    create_table :days, id: :uuid do |t|
      t.references :org, null: false, foreign_key: true, type: :uuid
      t.references :project, null: false, foreign_key: true, type: :uuid, index: false

      t.date :date, null: false
      t.timestamps

      t.index [:project_id, :date], unique: true
    end

    create_table :entries, id: :uuid do |t|
      t.references :day, null: false, foreign_key: true, type: :uuid
      t.references :org, null: false, foreign_key: true, type: :uuid
      t.references :member, null: false, foreign_key: true, type: :uuid

      t.text :log, null: false
      t.enum :status, null: false, enum_type: :entry_status, default: "doing"
      t.timestamps
    end

    create_table :integrations, id: :uuid do |t|
      t.references :org, null: false, foreign_key: true, type: :uuid

      t.string :integration_type, null: false
      t.string :service, null: false
      t.jsonb :credentials, default: {}, null: false
      t.text :template, null: false
      t.timestamps
    end

    create_table :project_integrations, id: :uuid do |t|
      t.references :org, null: false, foreign_key: true, type: :uuid
      t.references :project, null: false, foreign_key: true, type: :uuid, index: false
      t.references :integration, null: false, foreign_key: true, type: :uuid

      t.timestamps

      t.index [:project_id, :integration_id], unique: true
    end

    create_table :record_histories, id: :uuid do |t|
      t.references :org, null: false, foreign_key: true, type: :uuid, index: false

      t.boolean :done_by_admin, default: false, null: false
      t.string :user_id, null: false
      t.string :event, null: false
      t.uuid :record_id, null: false
      t.string :record_type, null: false
      t.jsonb :changes, default: {}, null: false

      t.timestamps

      t.index %i[done_by_admin user_id record_type]
      t.index %i[event record_type org_id]
      t.index %i[event record_type user_id]
      t.index %i[org_id record_type record_id]
    end
  end
end
