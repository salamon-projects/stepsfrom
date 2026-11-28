# An automatic listing (a Stay22 link or a site search) finds the property by
# name and position and often lands on a list of nearby places rather than its
# page. confirmed_at records that an admin checked a listing opens this
# property; until then the site says it searches for it. Listings an admin
# entered are their own confirmation.
class AddConfirmedAtToListings < ActiveRecord::Migration[8.1]
  def up
    add_column :listings, :confirmed_at, :datetime
    execute "UPDATE listings SET confirmed_at = updated_at WHERE generator IS NULL"
  end

  def down
    remove_column :listings, :confirmed_at
  end
end
