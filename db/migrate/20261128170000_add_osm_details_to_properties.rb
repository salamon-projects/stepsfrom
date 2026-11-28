# Keeps more of what OSM says about a property: all its tags, when it was
# last edited and its version; a tag showing it is mainly something else (a
# dive centre, a shop), which keeps it off the site until an admin approves
# it; the property it duplicates (the same place mapped twice); and its name
# in the local script when the site shows a Latin form.
class AddOsmDetailsToProperties < ActiveRecord::Migration[8.1]
  def change
    change_table :properties, bulk: true do |t|
      t.jsonb :osm_tags
      t.datetime :osm_timestamp
      t.integer :osm_version
      t.string :non_lodging_tag
      t.references :duplicate_of, foreign_key: { to_table: :properties, on_delete: :nullify }, index: { where: "duplicate_of_id IS NOT NULL" }
      t.string :local_name
    end
  end
end
