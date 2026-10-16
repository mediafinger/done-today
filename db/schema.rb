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

ActiveRecord::Schema[8.1].define(version: 2026_10_17_080000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "display_mode", ["system", "light", "dark"]
  create_enum "entry_status", ["todo", "doing", "done"]
  create_enum "org_role", ["guest", "member", "owner"]

  create_table "days", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.uuid "org_id", null: false
    t.uuid "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["org_id"], name: "index_days_on_org_id"
    t.index ["project_id", "date"], name: "index_days_on_project_id_and_date", unique: true
  end

  create_table "entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "day_end_minutes"
    t.uuid "day_id", null: false
    t.integer "day_start_minutes"
    t.integer "duration_minutes"
    t.integer "from_minutes"
    t.text "log", null: false
    t.uuid "member_id", null: false
    t.uuid "org_id", null: false
    t.enum "status", default: "doing", null: false, enum_type: "entry_status"
    t.text "tags", default: [], null: false, array: true
    t.integer "to_minutes"
    t.datetime "updated_at", null: false
    t.index ["day_id", "from_minutes"], name: "index_entries_on_day_id_and_from_minutes"
    t.index ["member_id"], name: "index_entries_on_member_id"
    t.index ["org_id"], name: "index_entries_on_org_id"
    t.index ["tags"], name: "index_entries_on_tags", using: :gin
  end

  create_table "invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "org_id", null: false
    t.uuid "invited_by_id"
    t.string "email", null: false
    t.string "name"
    t.datetime "sent_at", null: false
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.enum "role", default: "member", null: false, enum_type: "org_role"
    t.uuid "project_id"
    t.string "project_role"
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["org_id", "email"], name: "index_invitations_on_org_id_and_email_pending", unique: true, where: "(accepted_at IS NULL)"
    t.index ["org_id"], name: "index_invitations_on_org_id"
    t.index ["project_id"], name: "index_invitations_on_project_id"
  end

  create_table "members", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "org_id", null: false
    t.datetime "send_reminder_at"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.datetime "archived_at"
    t.enum "role", default: "member", null: false, enum_type: "org_role"
    t.index ["org_id", "user_id"], name: "index_members_on_org_id_and_user_id", unique: true
    t.index ["user_id"], name: "index_members_on_user_id"
  end

  create_table "orgs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_orgs_on_name", unique: true
    t.index ["slug"], name: "index_orgs_on_slug", unique: true
  end

  create_table "participants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "member_id", null: false
    t.uuid "org_id", null: false
    t.uuid "project_id", null: false
    t.text "roles", default: ["participant"], null: false, array: true
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_participants_on_member_id"
    t.index ["org_id"], name: "index_participants_on_org_id"
    t.index ["project_id", "member_id"], name: "index_participants_on_project_id_and_member_id", unique: true
  end

  create_table "projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "org_id", null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.datetime "archived_at"
    t.index ["org_id", "name"], name: "index_projects_on_org_id_and_name", unique: true
    t.index ["org_id", "slug"], name: "index_projects_on_org_id_and_slug", unique: true
  end

  create_table "record_histories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "done_by_admin", default: false, null: false
    t.string "event", null: false
    t.uuid "org_id", null: false
    t.jsonb "record_changes", default: {}, null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["done_by_admin", "user_id", "record_type"], name: "idx_on_done_by_admin_user_id_record_type_a6550ac183"
    t.index ["event", "record_type", "org_id"], name: "index_record_histories_on_event_and_record_type_and_org_id"
    t.index ["event", "record_type", "user_id"], name: "index_record_histories_on_event_and_record_type_and_user_id"
    t.index ["org_id", "record_type", "record_id"], name: "index_record_histories_on_org_id_and_record_type_and_record_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "admin", default: false
    t.text "bio"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.enum "display_mode", default: "system", null: false, enum_type: "display_mode"
    t.uuid "last_org_id"
    t.uuid "last_project_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_org_id"], name: "index_users_on_last_org_id"
    t.index ["last_project_id"], name: "index_users_on_last_project_id"
  end

  add_foreign_key "days", "orgs"
  add_foreign_key "days", "projects"
  add_foreign_key "entries", "days"
  add_foreign_key "entries", "members"
  add_foreign_key "entries", "orgs"
  add_foreign_key "invitations", "members", column: "invited_by_id"
  add_foreign_key "invitations", "orgs"
  add_foreign_key "invitations", "projects"
  add_foreign_key "members", "orgs"
  add_foreign_key "members", "users"
  add_foreign_key "participants", "members"
  add_foreign_key "participants", "orgs"
  add_foreign_key "participants", "projects"
  add_foreign_key "projects", "orgs"
  add_foreign_key "record_histories", "orgs"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "orgs", column: "last_org_id", on_delete: :nullify
  add_foreign_key "users", "projects", column: "last_project_id", on_delete: :nullify
end
