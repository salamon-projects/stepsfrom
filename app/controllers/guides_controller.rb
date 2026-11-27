class GuidesController < ApplicationController
  def show
    @guide = Guide.find_published(params[:id]) or raise ActiveRecord::RecordNotFound
    @destination = @guide.destination
    @properties = @guide.properties
    @offers = Offer.for_properties(@properties, current_stay)
  end
end
