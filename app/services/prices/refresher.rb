module Prices
  # Asks each provider for quotes and caches them in price_quotes.
  class Refresher
    def initialize(providers: Prices.providers)
      @providers = providers
    end

    def call(listings, stay)
      now = Time.current
      @providers.sum do |provider|
        supported = listings.select { |listing| provider.supports?(listing) }
        next 0 if supported.empty?

        rows = provider.quotes_for(supported, stay).map do |quote|
          { listing_id: quote.listing_id, check_in: stay.check_in, check_out: stay.check_out, adults: stay.adults,
            child_ages: stay.child_ages,
            total_cents: quote.total_cents, currency: quote.currency, source: provider.name,
            fetched_at: now, expires_at: now + provider.ttl }
        end
        PriceQuote.upsert_all(rows, unique_by: :index_price_quotes_on_listing_and_stay) if rows.any?
        rows.size
      rescue StandardError => e
        raise if Rails.env.local?

        Rails.logger.error("Price provider #{provider.name} failed: #{e.class}: #{e.message}")
        0
      end
    end
  end
end
