# Cross-site price lookup. Providers are plugged in once a booking site or
# aggregator grants API access; see Prices::Provider. Without providers the
# site shows links without prices.
module Prices
  Quote = Data.define(:listing_id, :total_cents, :currency)

  PENDING_TTL = 2.minutes

  def self.providers
    Array(Rails.configuration.x.price_providers).map { |name| "Prices::Providers::#{name.to_s.camelize}".constantize.new }
  end

  # Makes sure fresh quotes for the stay exist or are on their way. Inline
  # providers answer during the request; others run in RefreshPricesJob.
  def self.refresh(listings, stay)
    providers = self.providers
    return if providers.empty? || stay.nil? || !stay.valid?

    fresh_ids = PriceQuote.fresh.for_stay(stay).where(listing_id: listings.map(&:id)).pluck(:listing_id)
    stale = listings.reject { |listing| fresh_ids.include?(listing.id) }
    return if stale.empty?

    if providers.all?(&:inline?)
      Refresher.new(providers:).call(stale, stay)
    else
      key = [ "prices-pending", stay.to_params, stale.map(&:id).sort ].to_param
      return if Rails.cache.exist?(key)

      Rails.cache.write(key, true, expires_in: PENDING_TTL)
      RefreshPricesJob.perform_later(stale.map(&:id), stay.to_params)
    end
  end
end
