# Logs a click-out and redirects to the booking site (through the affiliate
# tracking URL when configured).
class OutboundController < ApplicationController
  def show
    listing = Listing.active.includes(:property).find(params[:listing_id])
    stay = current_stay

    OutboundClick.create!(
      listing:, property: listing.property, provider: listing.provider,
      check_in: stay&.check_in, check_out: stay&.check_out, adults: stay&.adults, children: stay&.children,
      source_path: source_path
    )

    response.set_header("X-Robots-Tag", "noindex, nofollow")
    redirect_to Affiliate::LinkBuilder.new(listing, stay).url, allow_other_host: true
  end

  private

  # Path of the page the visitor clicked on, without host or query string.
  def source_path
    referer = URI.parse(request.referer.to_s)
    referer.path.presence if referer.host.nil? || referer.host == request.host
  rescue URI::InvalidURIError
    nil
  end
end
