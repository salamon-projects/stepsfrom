# Searches can include children: prices are cached per child ages, and
# click-outs record how many children were searched for.
class AddChildrenToStays < ActiveRecord::Migration[8.1]
  def change
    add_column :price_quotes, :child_ages, :integer, array: true, default: [], null: false
    remove_index :price_quotes, name: "index_price_quotes_on_listing_and_stay"
    add_index :price_quotes, [ :listing_id, :check_in, :check_out, :adults, :child_ages ],
              name: "index_price_quotes_on_listing_and_stay", unique: true
    add_column :outbound_clicks, :children, :integer
  end
end
