# Adds, updates or removes automatic booking-site listings (see
# Affiliate::AutoListings), for one destination or every one.
class AutoListingsJob < ApplicationJob
  queue_as :default

  def perform(destination_id = nil)
    properties = destination_id ? Property.where(destination_id:) : Property.all
    Affiliate::AutoListings.new(properties).call
  end
end
