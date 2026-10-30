# Lets an import tell what OSM no longer has: map features record when an
# import last returned them, properties when they went missing.
class TrackOsmPresence < ActiveRecord::Migration[8.1]
  def change
    add_column :water_features, :seen_at, :datetime
    add_column :beaches, :seen_at, :datetime
    add_column :road_segments, :seen_at, :datetime
    add_column :properties, :osm_missing_since, :datetime
  end
end
