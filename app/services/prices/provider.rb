module Prices
  # Interface for a price source. Implementations must use an official API
  # of the booking site or of a licensed aggregator; never scraping.
  class Provider
    # Unique name stored on PriceQuote#source.
    def name
      self.class.name.demodulize.underscore
    end

    # Whether the provider is fast enough to ask during a page request.
    def inline?
      false
    end

    # How long a quote may be shown.
    def ttl
      6.hours
    end

    def supports?(listing)
      raise NotImplementedError
    end

    # Returns Prices::Quote objects for the listings it found prices for.
    def quotes_for(listings, stay)
      raise NotImplementedError
    end
  end
end
