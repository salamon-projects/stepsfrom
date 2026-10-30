require "net/http"

module Osm
  # Minimal client for the Overpass API (https://wiki.openstreetmap.org/wiki/Overpass_API).
  class OverpassClient
    class Error < StandardError; end

    DEFAULT_URL = "https://overpass-api.de/api/interpreter".freeze
    USER_AGENT = "stepsfrom/1.0 (+https://stepsfrom.com; waterfront verification)".freeze

    def initialize(url: ENV.fetch("OVERPASS_URL", DEFAULT_URL), timeout: 300)
      @uri = URI(url)
      @timeout = timeout
    end

    # Runs an Overpass QL query and returns its elements as Osm::Element.
    def query(ql)
      response = Net::HTTP.start(@uri.host, @uri.port, use_ssl: @uri.scheme == "https",
                                 open_timeout: 15, read_timeout: @timeout) do |http|
        request = Net::HTTP::Post.new(@uri)
        request["User-Agent"] = USER_AGENT
        request.set_form_data(data: ql)
        http.request(request)
      end
      raise Error, "Overpass returned HTTP #{response.code}: #{response.body.to_s[0, 200]}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).fetch("elements").map { |json| Element.from_json(json) }
    rescue JSON::ParserError, KeyError => e
      raise Error, "Unexpected Overpass response: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => e
      raise Error, "Overpass request failed: #{e.message}"
    end
  end
end
