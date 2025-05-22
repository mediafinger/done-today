class AddSlugToOrgAndProject < ActiveRecord::Migration[8.0]
  def change
    add_column :orgs, :slug, :string
    add_index :orgs, :slug, unique: true

    add_column :projects, :slug, :string
    add_index :projects, :slug, unique: true

    Org.all.each { it.update_column(:slug, it.name.parameterize) }
    Project.all.each { it.update_column(:slug, it.name.parameterize) }
  end
end
