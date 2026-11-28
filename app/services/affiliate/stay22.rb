module Affiliate
  # Stay22 Allez links (https://dev.stay22.com/docs/allez). Stay22 finds the
  # property on a booking site by its name and position and forwards the
  # visitor there with our affiliate id, so a property can be bookable before
  # anyone has looked up its page on each site. Used for automatic listings.
  module Stay22
    HOST = "www.stay22.com"
    STAY_PARAMS = %w[aid campaign checkin checkout adults children childrenAges].freeze

    def self.aid
      ENV["STAY22_AID"].presence
    end

    def self.configured?
      aid.present?
    end

    def self.link?(url)
      URI.parse(url.to_s).host == HOST
    rescue URI::InvalidURIError
      false
    end

    # The link kept on the listing: which site, and what to look for there.
    def self.listing_url(property, endpoint)
      query = { hotelname: property.name, lat: property.latitude.round(6), lng: property.longitude.round(6) }
      "https://#{HOST}/allez/#{endpoint}?#{URI.encode_www_form(query)}"
    end

    # The link a visitor follows: the listing's link with our affiliate id,
    # the page's campaign and the visitor's stay.
    def self.outbound_url(url, stay: nil, campaign: nil)
      uri = URI.parse(url)
      query = URI.decode_www_form(uri.query.to_s).reject { |key, _| STAY_PARAMS.include?(key) }
      query << [ "aid", aid ] if aid
      query << [ "campaign", campaign_param(campaign) ] if campaign.present?
      query.concat(stay_query(stay)) if stay
      uri.query = URI.encode_www_form(query)
      uri.to_s
    end

    # Stay22's map of places to stay with live prices
    # (https://dev.stay22.com/docs/maps/parameters), centred on a point. Nil
    # without our affiliate id. Pages load it only when the visitor asks.
    def self.map_url(lat:, lng:, zoom:, stay: nil, campaign: nil)
      return unless configured?

      query = [ [ "aid", aid ], [ "lat", lat.round(6) ], [ "lng", lng.round(6) ], [ "zoom", zoom ] ]
      query << [ "campaign", campaign_param(campaign) ] if campaign.present?
      if stay&.valid?
        query.push([ "checkin", stay.check_in.iso8601 ], [ "checkout", stay.check_out.iso8601 ], [ "adults", stay.adults ])
        query << [ "children", stay.children ] if stay.children.positive?
      end
      "https://#{HOST}/embed/gm?#{URI.encode_www_form(query)}"
    end

    # Stay22 splits campaigns on "-", so keep them to word characters.
    def self.campaign_param(campaign)
      campaign.to_s.gsub(/\W+/, "_")
    end
    private_class_method :campaign_param

    def self.stay_query(stay)
      query = [ [ "checkin", stay.check_in.iso8601 ], [ "checkout", stay.check_out.iso8601 ], [ "adults", stay.adults.to_s ] ]
      if stay.children.positive?
        query << [ "children", stay.children.to_s ]
        query << [ "childrenAges", stay.child_ages.join(",") ]
      end
      query
    end
    private_class_method :stay_query
  end
end
