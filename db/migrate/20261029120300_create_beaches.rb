class CreateBeaches < ActiveRecord::Migration[8.1]
  def change
    create_table :beaches do |t|
      t.string :osm_type, null: false
      t.bigint :osm_id, null: false
      t.string :name
      t.string :surface
      t.st_polygon :geom, geographic: true, null: false
      t.timestamps
    end
    add_index :beaches, [ :osm_type, :osm_id ], unique: true
    add_index :beaches, :geom, using: :gist
  end
end
