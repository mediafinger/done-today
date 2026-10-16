# Project slugs are looked up per org, so they only need to be unique per org.
# Existing suffixed slugs (e.g. "website-42") are kept: renaming them would break bookmarked links.
#
class ScopeProjectSlugsToOrg < ActiveRecord::Migration[8.1]
  def change
    remove_index :projects, :slug, unique: true
    add_index :projects, %i[org_id slug], unique: true
  end
end
