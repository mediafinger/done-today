class AddNameToMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :members, :name, :string, null: false
  end
end
