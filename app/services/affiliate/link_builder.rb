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

      replaced = @provider.params.keys + @provider.child_params.keys
      query = URI.decode_www_form(uri.query.to_s).reject { |key, _| replaced.include?(key) }
      @provider.params.each do |key, template|
        value = interpolate(template, stay_values)
        query << [ key, value ] if value.present?
      end
      @stay.child_ages.each do |age|
        @provider.child_params.each { |key, template| query << [ key, interpolate(template, "age" => age.to_s) ] }
      end
      uri.query = URI.encode_www_form(query)
      uri.to_s
    end

    private

    def stay_values
      @stay_values ||= {
        "check_in" => @stay.check_in.iso8601,
        "check_out" => @stay.check_out.iso8601,
        "adults" => @stay.adults.to_s,
        "nights" => @stay.nights.to_s,
        "children" => @stay.children.to_s,
        "child_ages" => @stay.child_ages.map { |age| interpolate(@provider.child_age, "age" => age.to_s) }
                             .join(@provider.child_age_separator)
      }
    end

    def interpolate(template, values)
      template.to_s.gsub(PLACEHOLDER) { values.fetch(Regexp.last_match(1)) }
    end
  end
end
