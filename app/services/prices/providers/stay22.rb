module Prices
  module Providers
    # Live prices from the Stay22 Direct Travel API
    # (https://dev.stay22.com/docs/api), which answers for Booking.com,
    # Expedia, Hotels.com, Vrbo and others in one call. Needs an approved key
    # in STAY22_API_KEY.
    #
    # Stay22 returns accommodations by area, not by our listings, so each
    # result is matched to one of our properties by position (and name when
    # it is further off), and its suppliers' prices go to that property's
    # listings for the same booking sites.
    #
    # Stay22's terms allow caching responses for at most 60 minutes and no
    # long-term storage, hence the TTL below and the hourly purge in
    # config/recurring.yml.
    class Stay22 < Provider
      ENDPOINT = "https://api.stay22.com/v3/accommodations".freeze
      CURRENCY = "EUR".freeze
      PAGE_SIZE = 100
      MAX_PAGES = 10
      # Up to this many properties of one destination are looked up one by
      # one; more are fetched with one search over the destination's area.
      SINGLE_LOOKUPS = 5
      RADIUS_M = 250
      # A result this close is the property whatever its name; up to
      # MAX_DISTANCE_M it must share a word of the name.
      SURE_DISTANCE_M = 40
      MAX_DISTANCE_M = 250
      # Words that say nothing about which property it is.
      COMMON_WORDS = %w[hotel hotels apartment apartments apartmani studios studio rooms villa villas suites resort beach the and].freeze

      Result = Data.define(:name, :lat, :lng, :prices)

      def initialize(api_key: ENV["STAY22_API_KEY"])
        raise "STAY22_API_KEY is not set" if api_key.blank?

        @api_key = api_key
        super()
      end

      def ttl
        55.minutes
      end

      def supports?(listing)
        listing.property.present?
      end

      def quotes_for(listings, stay)
        listings.group_by { |listing| listing.property.destination }.flat_map do |destination, group|
          properties = group.map(&:property).uniq
          results = properties.size <= SINGLE_LOOKUPS ? properties.flat_map { |p| around(p, stay) } : within(destination, stay)
          quotes(group, match(properties, results))
        end
      end

      private

      # { property => Result } for the properties a result was found for.
      def match(properties, results)
        properties.each_with_object({}) do |property, matched|
          candidates = results.filter_map do |result|
            distance = distance_m(property, result)
            next if distance > MAX_DISTANCE_M
            next if distance > SURE_DISTANCE_M && !same_name?(property.name, result.name)

            [ distance, result ]
          end
          best = candidates.min_by(&:first)
          matched[property] = best.last if best
        end
      end

      def quotes(listings, matched)
        listings.filter_map do |listing|
          result = matched[listing.property] or next
          total = result.prices[supplier_key(listing.provider)] or next

          Quote.new(listing_id: listing.id, total_cents: (total * 100).round, currency: CURRENCY)
        end
      end

      def around(property, stay)
        fetch(stay, lat: property.latitude, lng: property.longitude, radius: RADIUS_M, pageSize: 20)
      end

      def within(destination, stay)
        area = { nelat: destination.north, nelng: destination.east, swlat: destination.south, swlng: destination.west }
        (1..MAX_PAGES).each_with_object([]) do |page, results|
          batch, more = fetch_page(stay, area.merge(pageSize: PAGE_SIZE, page:))
          results.concat(batch)
          break results unless more
        end
      end

      def fetch(stay, query)
        fetch_page(stay, query).first
      end

      # Returns [results, more_pages?].
      def fetch_page(stay, query)
        query = query.merge(stay_query(stay), currency: CURRENCY, aid: Affiliate::Stay22.aid).compact
        uri = URI(ENDPOINT)
        uri.query = URI.encode_www_form(query)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
          request = Net::HTTP::Get.new(uri)
          request["X-API-KEY"] = @api_key
          request["Accept"] = "application/json"
          http.request(request)
        end
        raise "Stay22 API #{response.code}: #{response.body.to_s.truncate(200)}" unless response.is_a?(Net::HTTPSuccess)

        body = JSON.parse(response.body)
        meta = body["meta"] || {}
        # Stay22 falls back to USD for currencies it can't convert to.
        return [ [], false ] unless meta["currency"].to_s.upcase == CURRENCY

        [ Array(body["results"]).filter_map { |item| result(item) }, meta["hasMore"] == true ]
      end

      def stay_query(stay)
        query = { checkin: stay.check_in.iso8601, checkout: stay.check_out.iso8601, adults: stay.adults }
        query.merge!(children: stay.children, childrenAges: stay.child_ages.join(",")) if stay.children.positive?
        query
      end

      def result(item)
        coordinates = item.dig("location", "coordinates") || {}
        lat = coordinates["lat"]
        lng = coordinates["lng"]
        return unless lat.is_a?(Numeric) && lng.is_a?(Numeric)

        # A null or missing price means "not known", never free or sold out.
        prices = (item["suppliers"] || {}).each_with_object({}) do |(supplier, details), found|
          total = details.is_a?(Hash) ? details.dig("price", "total") : nil
          found[supplier_key(supplier)] = total.to_f if total.is_a?(Numeric) && total.positive?
        end
        Result.new(name: item["name"].to_s, lat:, lng:, prices:) if prices.any?
      end

      # "hotels_com", "hotels.com" and "hotelscom" are the same site.
      def supplier_key(name)
        name.to_s.downcase.gsub(/[^a-z0-9]/, "")
      end

      def same_name?(ours, theirs)
        (words(ours) & words(theirs)).any?
      end


      def words(name)
        name.to_s.downcase.scan(/[[:alnum:]]{3,}/) - COMMON_WORDS
      end

      def distance_m(property, result)
        lat1, lng1, lat2, lng2 = [ property.latitude, property.longitude, result.lat, result.lng ].map { |deg| deg.to_f * Math::PI / 180 }
        a = Math.sin((lat2 - lat1) / 2)**2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin((lng2 - lng1) / 2)**2
        2 * 6_371_000 * Math.asin(Math.sqrt(a))
      end
    end
  end
end
