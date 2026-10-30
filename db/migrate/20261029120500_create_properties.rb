class CreateProperties < ActiveRecord::Migration[8.1]
  def change
    create_table :properties do |t|
      t.references :destination, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :kind, null: false, default: "hotel"
      t.integer :stars
      t.string :address
      t.string :website
      t.string :osm_type
      t.bigint :osm_id
      t.st_point :lonlat, geographic: true, null: false
      t.st_polygon :footprint, geographic: true
      # Largest distance between our position and one a booking site reports
      t.integer :coord_mismatch_m
      t.timestamps
    end
    add_index :properties, :slug, unique: true
    add_index :properties, [ :osm_type, :osm_id ], unique: true, where: "osm_id IS NOT NULL"
    add_index :properties, :lonlat, using: :gist
    add_index :properties, :footprint, using: :gist
  end
end
