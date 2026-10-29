class CreateDestinations < ActiveRecord::Migration[8.1]
  def change
    create_table :destinations do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :country_code, limit: 2, null: false
      t.string :sea_name
      t.text :summary
      t.st_polygon :area, geographic: true, null: false
      t.st_point :center, geographic: true, null: false
      t.integer :zoom, null: false, default: 12
      t.integer :position, null: false, default: 0
      t.boolean :published, null: false, default: false
      t.timestamps
    end
    add_index :destinations, :slug, unique: true
    add_index :destinations, :area, using: :gist
  end
end
