class CreateRoadSegments < ActiveRecord::Migration[8.1]
  def change
    create_table :road_segments do |t|
      t.bigint :osm_id, null: false
      t.string :category, null: false
      t.string :highway
      t.string :name
      t.line_string :geom, geographic: true, null: false
      t.timestamps
    end
    add_index :road_segments, :osm_id, unique: true
    add_index :road_segments, :geom, using: :gist
  end
end
