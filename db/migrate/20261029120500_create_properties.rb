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

      # Measurement results, written by Waterfront::Measurement
      t.references :water_feature, foreign_key: { on_delete: :nullify }
      t.string :water_kind
      t.string :water_name
      t.st_point :water_point, geographic: true
      t.integer :distance_to_water_m
      t.integer :distance_to_beach_m
      t.string :beach_surface
      t.boolean :crosses_road, null: false, default: false
      t.boolean :crosses_promenade, null: false, default: false
      t.integer :coord_mismatch_m
      t.string :waterfront_category, null: false, default: "unknown"
      t.datetime :classified_at

      t.string :qa_status, null: false, default: "pending"
      t.text :qa_note
      t.timestamps
    end
    add_index :properties, :slug, unique: true
    add_index :properties, [ :osm_type, :osm_id ], unique: true, where: "osm_id IS NOT NULL"
    add_index :properties, [ :destination_id, :waterfront_category ]
    add_index :properties, :qa_status
    add_index :properties, :lonlat, using: :gist
    add_index :properties, :footprint, using: :gist
  end
end
