class PropertiesController < ApplicationController
  before_action :redirect_excluded_kind, :redirect_duplicate

  def show
    @property = Property.published.preload(:destination, :active_listings, :waterfront).find_by!(slug: params[:id])
    @stay = Stay.from_params(params)
    @prices_pending = Prices.refresh(@property.active_listings.to_a, current_stay) if current_stay
    @offers = Offer.for_properties([ @property ], current_stay).fetch(@property.id, [])
  end

  private

  # A kind kept off the site (config/listing.yml) moves permanently to its
  # destination page, so search engines drop the old URL.
  def redirect_excluded_kind
    property = Property.where(kind: Property.excluded_kinds).find_by(slug: params[:id]) or return
    destination = Destination.published.find_by(id: property.destination_id) or return

    redirect_to destination_path(destination), status: :moved_permanently
  end

  # The same place mapped twice in OSM: its page moves to the one listed.
  def redirect_duplicate
    property = Property.where.not(duplicate_of_id: nil).find_by(slug: params[:id]) or return
    original = Property.published.find_by(id: property.duplicate_of_id) or return

    redirect_to property_path(original), status: :moved_permanently
  end
end
