class RefreshPricesJob < ApplicationJob
  queue_as :default

  def perform(listing_ids, stay_params)
    stay = Stay.new(stay_params.symbolize_keys)
    return unless stay.valid?

    Prices::Refresher.new.call(Listing.active.where(id: listing_ids).to_a, stay)
  end
end
