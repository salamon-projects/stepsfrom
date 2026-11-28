module Admin
  # Automatic booking links nobody has checked yet, the most clicked first:
  # open each, then confirm it or paste the property's own page.
  class BookingLinksController < BaseController
    PER_PAGE = 50

    def index
      scope = Listing.active.unconfirmed.joins(:property).merge(Property.published)
      @total = scope.count
      clicks = "(SELECT COUNT(*) FROM outbound_clicks c WHERE c.listing_id = listings.id)"
      @listings = scope.includes(property: :destination)
                       .select("listings.*, #{clicks} AS clicks_count")
                       .order(Arel.sql("clicks_count DESC"), "properties.name", "listings.provider")
                       .limit(PER_PAGE)
    end
  end
end
