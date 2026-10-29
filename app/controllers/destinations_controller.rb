class DestinationsController < ApplicationController
  def show
    @destination = Destination.published.find_by!(slug: params[:id])
    @stay = Stay.from_params(params)

    if current_stay
      Prices.refresh(Listing.active.where(property_id: @destination.properties.published.select(:id)).to_a, current_stay)
    end

    @search = PropertySearch.new(destination: @destination, stay: current_stay,
                                 params: params.permit(:category, :surface, :kind, :sort))
    @pagy, @properties = pagy(@search.results)
    return if redirect_past_last_page(@pagy)

    @offers = Offer.for_properties(@properties, current_stay)
    @map_points = @search.filtered.map { |property| helpers.map_point(property, url: property_path(property, helpers.stay_params)) }
  end
end
