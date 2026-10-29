class CreateOutboundClicks < ActiveRecord::Migration[8.1]
  def change
    create_table :outbound_clicks do |t|
      t.references :listing, foreign_key: { on_delete: :nullify }
      t.references :property, foreign_key: { on_delete: :nullify }
      t.string :provider, null: false
      t.date :check_in
      t.date :check_out
      t.integer :adults
      t.string :source_path
      t.datetime :created_at, null: false
    end
    add_index :outbound_clicks, :created_at
  end
end
