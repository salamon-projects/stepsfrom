class GuidesController < ApplicationController
  def show
    @guide = Guide.find_published(params[:id]) or raise ActiveRecord::RecordNotFound
    @destination = @guide.destination
    @properties = @guide.properties
    @stay = Stay.from_params(params)

    # Prices as on destination pages; the ranking stays by measured distance.
    if current_stay
      @prices_pending = Prices.refresh(Listing.active.where(property_id: @properties.map(&:id)).to_a, current_stay)
    end

    @offers = Offer.for_properties(@properties, current_stay)
  end
end
