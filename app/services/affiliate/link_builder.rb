module Affiliate
  # Builds the outbound URL for a listing: the booking site's page with the
  # visitor's stay filled in, wrapped in the programme's tracking URL when
  # one is configured.
  class LinkBuilder
    PLACEHOLDER = /\{(\w+)\}/

    def initialize(listing, stay = nil)
      @listing = listing
      @provider = listing.provider_config
      @stay = stay if stay&.valid?
    end

    def url
      template = @provider.tracking_template
      template ? template.gsub("{url}") { CGI.escape(target_url) } : target_url
    end

    def target_url
      uri = URI.parse(@listing.url)
      return uri.to_s unless @stay && @provider.params.any?

      query = URI.decode_www_form(uri.query.to_s).reject { |key, _| @provider.params.key?(key) }
      @provider.params.each { |key, template| query << [ key, interpolate(template) ] }
      uri.query = URI.encode_www_form(query)
      uri.to_s
    end

    private

    def interpolate(template)
      values = {
        "check_in" => @stay.check_in.iso8601,
        "check_out" => @stay.check_out.iso8601,
        "adults" => @stay.adults.to_s,
        "nights" => @stay.nights.to_s
      }
      template.to_s.gsub(PLACEHOLDER) { values.fetch(Regexp.last_match(1)) }
    end
  end
end
