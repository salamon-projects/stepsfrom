class CreatePriceQuotes < ActiveRecord::Migration[8.1]
  def change
    create_table :price_quotes do |t|
      t.references :listing, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.date :check_in, null: false
      t.date :check_out, null: false
      t.integer :adults, null: false
      t.integer :total_cents, null: false
      t.string :currency, limit: 3, null: false, default: "EUR"
      t.string :source, null: false
      t.datetime :fetched_at, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :price_quotes, [ :listing_id, :check_in, :check_out, :adults ], unique: true, name: "index_price_quotes_on_listing_and_stay"
    add_index :price_quotes, :expires_at
  end
end
