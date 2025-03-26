# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_03_26_132421) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "entry_status", ["todo", "doing", "done"]

  create_table "days", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "org_id", null: false
    t.uuid "project_id", null: false
    t.date "date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["org_id"], name: "index_days_on_org_id"
    t.index ["project_id", "date"], name: "index_days_on_project_id_and_date", unique: true
  end

  create_table "entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "day_id", null: false
    t.uuid "org_id", null: false
    t.uuid "member_id", null: false
    t.text "log", null: false
    t.enum "status", default: "doing", null: false, enum_type: "entry_status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["day_id"], name: "index_entries_on_day_id"
    t.index ["member_id"], name: "index_entries_on_member_id"
    t.index ["org_id"], name: "index_entries_on_org_id"
  end

  create_table "integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "org_id", null: false
    t.string "integration_type", null: false
    t.string "service", null: false
    t.jsonb "credentials", default: {}, null: false
    t.text "template", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["org_id"], name: "index_integrations_on_org_id"
  end

  create_table "members", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "org_id", null: false
    t.uuid "user_id", null: false
    t.text "roles", default: ["member"], null: false, array: true
    t.datetime "send_reminder_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["org_id", "user_id"], name: "index_members_on_org_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_members_on_user_id"
  end

  create_table "orgs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_orgs_on_name", unique: true
  end

  create_table "participants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "org_id", null: false
    t.uuid "project_id", null: false
    t.uuid "member_id", null: false
    t.text "roles", default: ["participant"], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_participants_on_member_id"
    t.index ["org_id"], name: "index_participants_on_org_id"
    t.index ["project_id", "member_id"], name: "index_participants_on_project_id_and_member_id", unique: true
  end

  create_table "project_integrations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "org_id", null: false
    t.uuid "project_id", null: false
    t.uuid "integration_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["integration_id"], name: "index_project_integrations_on_integration_id"
    t.index ["org_id"], name: "index_project_integrations_on_org_id"
    t.index ["project_id", "integration_id"], name: "index_project_integrations_on_project_id_and_integration_id", unique: true
  end

  create_table "projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "org_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["org_id", "name"], name: "index_projects_on_org_id_and_name", unique: true
  end

  create_table "record_histories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "org_id", null: false
    t.boolean "done_by_admin", default: false, null: false
    t.string "user_id", null: false
    t.string "event", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.jsonb "changes", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["done_by_admin", "user_id", "record_type"], name: "idx_on_done_by_admin_user_id_record_type_a6550ac183"
    t.index ["event", "record_type", "org_id"], name: "index_record_histories_on_event_and_record_type_and_org_id"
    t.index ["event", "record_type", "user_id"], name: "index_record_histories_on_event_and_record_type_and_user_id"
    t.index ["org_id", "record_type", "record_id"], name: "index_record_histories_on_org_id_and_record_type_and_record_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "name", null: false
    t.text "bio"
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "days", "orgs"
  add_foreign_key "days", "projects"
  add_foreign_key "entries", "days"
  add_foreign_key "entries", "members"
  add_foreign_key "entries", "orgs"
  add_foreign_key "integrations", "orgs"
  add_foreign_key "members", "orgs"
  add_foreign_key "members", "users"
  add_foreign_key "participants", "members"
  add_foreign_key "participants", "orgs"
  add_foreign_key "participants", "projects"
  add_foreign_key "project_integrations", "integrations"
  add_foreign_key "project_integrations", "orgs"
  add_foreign_key "project_integrations", "projects"
  add_foreign_key "projects", "orgs"
  add_foreign_key "record_histories", "orgs"
  add_foreign_key "sessions", "users"
end
