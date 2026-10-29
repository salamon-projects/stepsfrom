module Prices
  module Providers
    # Deterministic made-up prices for development and tests only.
    class Fake < Provider
      def initialize
        raise "Prices::Providers::Fake must not run in production" if Rails.env.production?

        super
      end

      def inline?
        true
      end

      def supports?(_listing)
        true
      end

      def quotes_for(listings, stay)
        listings.map do |listing|
          seed = Digest::SHA256.hexdigest([ listing.id, listing.provider, stay.check_in, stay.adults ].join(":")).to_i(16)
          nightly_cents = 6_000 + (seed % 18_000)
          Quote.new(listing_id: listing.id, total_cents: nightly_cents * stay.nights, currency: "EUR")
        end
      end
    end
  end
end
