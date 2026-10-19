class AddTimesRequiredToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :times_required, :boolean, default: false, null: false
  end
end
