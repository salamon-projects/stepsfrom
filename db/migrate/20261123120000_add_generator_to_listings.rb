# Listings StepsFrom creates itself (a Stay22 link or a Booking.com search
# for the property) record how they were made; null means an admin entered it.
class AddGeneratorToListings < ActiveRecord::Migration[8.1]
  def change
    add_column :listings, :generator, :string
  end
end
