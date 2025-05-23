class AddProjectToSession < ActiveRecord::Migration[8.0]
  def change
    add_reference :sessions, :project, null: true, foreign_key: true, type: :uuid
  end
end
