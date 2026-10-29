class CreateListings < ActiveRecord::Migration[8.1]
  def change
    create_table :listings do |t|
      t.references :property, null: false, foreign_key: { on_delete: :cascade }
      t.string :provider, null: false
      t.string :url, null: false
      t.string :external_id
      t.st_point :reported_lonlat, geographic: true
      t.boolean :claims_beachfront
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :listings, [ :property_id, :provider ], unique: true
  end
end
