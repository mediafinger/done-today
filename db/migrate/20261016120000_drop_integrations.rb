class DropIntegrations < ActiveRecord::Migration[8.1]
  def up
    drop_table :project_integrations
    drop_table :integrations
  end

  def down
    create_table :integrations, id: :uuid do |t|
      t.references :org, null: false, foreign_key: true, type: :uuid
      t.string :integration_type, null: false
      t.string :service, null: false
      t.jsonb :credentials, null: false, default: {}
      t.text :template, null: false

      t.timestamps
    end

    create_table :project_integrations, id: :uuid do |t|
      t.references :org, null: false, foreign_key: true, type: :uuid
      t.references :project, null: false, foreign_key: true, type: :uuid, index: false
      t.references :integration, null: false, foreign_key: true, type: :uuid
      t.index %i[project_id integration_id], unique: true

      t.timestamps
    end
  end
end
