class AddDisplayModeToUsers < ActiveRecord::Migration[8.1]
  def change
    create_enum :display_mode, %w[system light dark]

    add_column :users, :display_mode, :enum, enum_type: :display_mode, default: "system", null: false
  end
end
