class CreateWaterFeatures < ActiveRecord::Migration[8.1]
  def change
    create_table :water_features do |t|
      t.string :osm_type, null: false
      t.bigint :osm_id, null: false
      t.string :kind, null: false
      t.string :name
      t.geometry :geom, geographic: true, null: false
      t.timestamps
    end
    add_index :water_features, [ :osm_type, :osm_id ], unique: true
    add_index :water_features, :geom, using: :gist
  end
end
