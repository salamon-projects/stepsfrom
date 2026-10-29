# A listing as shown to visitors, with its price for the searched stay when a
# fresh one is known. The cheapest priced offer is marked best.
Offer = Data.define(:listing, :quote, :best) do
  # Returns { property_id => [Offer, ...] }, cheapest first, then in the
  # configured provider order.
  def self.for_properties(properties, stay)
    listings = properties.flat_map(&:active_listings)
    quotes = quotes_for(listings, stay)
    provider_order = Affiliate::Provider.keys

    listings.group_by(&:property_id).transform_values do |property_listings|
      sorted = property_listings.sort_by do |listing|
        quote = quotes[listing.id]
        [ quote ? 0 : 1, quote&.total_cents.to_i, provider_order.index(listing.provider) || provider_order.size ]
      end
      best_id = sorted.first.id if quotes[sorted.first.id]
      sorted.map { |listing| new(listing:, quote: quotes[listing.id], best: listing.id == best_id) }
    end
  end

  def self.quotes_for(listings, stay)
    return {} unless stay&.valid? && listings.any?

    PriceQuote.fresh.for_stay(stay).where(listing_id: listings.map(&:id), currency: "EUR").index_by(&:listing_id)
  end
end
