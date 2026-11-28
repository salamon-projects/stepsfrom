module Affiliate
  # Makes properties bookable without anyone looking up their page on each
  # booking site. For every site that has a way to find a property, it adds an
  # automatic listing: a search of the site's own programme for the property's
  # name once that programme is set up (search_url + tracking_env in
  # config/affiliates.yml), otherwise a Stay22 link (stay22, with STAY22_AID).
  #
  # What an admin decided always wins: listings an admin entered are never
  # touched, an automatic listing an admin switched off stays off, and an
  # automatic listing whose URL an admin edited becomes the admin's. An
  # automatic listing is unconfirmed (Listing#confirmed?) until an admin checks
  # that it opens the property's own page.
  class AutoListings
    def initialize(properties = Property.all)
      @properties = properties
    end

    # Returns how many listings were created, updated and removed.
    def call
      counts = { created: 0, updated: 0, removed: 0 }
      @properties.where(osm_missing_since: nil).includes(:destination, :listings).find_each do |property|
        Provider.all.each_value do |provider|
          result = sync(property, provider)
          counts[result] += 1 if result
        end
      end
      counts
    end

    private

    def sync(property, provider)
      listing = property.listings.find { |existing| existing.provider == provider.key }
      generator = generator_for(provider)

      if listing.nil?
        return unless generator

        property.listings.create!(provider: provider.key, generator:, url: url_for(property, provider, generator))
        :created
      elsif !listing.automatic? || !listing.active?
        nil
      elsif generator.nil?
        listing.destroy!
        :removed
      else
        url = url_for(property, provider, generator)
        return if listing.url == url && listing.generator == generator

        # A new link (the name or position changed) has to be checked again.
        listing.update!(url:, generator:, confirmed_at: nil)
        :updated
      end
    end

    def generator_for(provider)
      if provider.search_url && provider.tracking_configured?
        "search"
      elsif provider.stay22_endpoint && Stay22.configured?
        "stay22"
      end
    end

    def url_for(property, provider, generator)
      case generator
      when "search"
        "#{provider.search_url}?#{URI.encode_www_form(ss: "#{property.name}, #{property.destination.name}")}"
      when "stay22"
        Stay22.listing_url(property, provider.stay22_endpoint)
      end
    end
  end
end
