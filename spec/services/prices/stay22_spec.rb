require "rails_helper"

RSpec.describe Prices::Providers::Stay22 do
  subject(:provider) { described_class.new(api_key: "test-key") }

  let(:destination) { create(:destination) }
  let(:property) { create(:property, destination:, name: "Hotel Riva", latitude: 43.3, longitude: 17.02) }
  let!(:booking) { create(:listing, property:) }
  let!(:expedia) { create(:listing, :expedia, property:) }
  let(:stay) { Stay.new(check_in: Date.current + 20, check_out: Date.current + 23, adults: 2, children: 1, child_ages: [ 6 ]) }

  def accommodation(name:, lat:, lng:, suppliers:)
    { "name" => name, "location" => { "coordinates" => { "lat" => lat, "lng" => lng } },
      "suppliers" => suppliers.transform_values { |total| { "price" => total.nil? ? nil : { "total" => total } } } }
  end

  def respond_with(results, currency: "EUR", more: false)
    { status: 200, headers: { "Content-Type" => "application/json" },
      body: { meta: { currency:, hasMore: more }, results: }.to_json }
  end

  it "asks around the property with the stay and gives each booking site its price" do
    request = stub_request(:get, %r{\Ahttps://api\.stay22\.com/v3/accommodations})
      .with(headers: { "X-API-KEY" => "test-key" },
            query: hash_including("lat" => "43.3", "lng" => "17.02", "checkin" => stay.check_in.iso8601,
                                  "checkout" => stay.check_out.iso8601, "adults" => "2", "children" => "1",
                                  "childrenAges" => "6", "currency" => "EUR"))
      .to_return(respond_with([ accommodation(name: "Riva Hotel", lat: 43.3001, lng: 17.0201,
                                              suppliers: { "booking" => 420.5, "expedia" => 399 }) ]))

    quotes = provider.quotes_for([ booking, expedia ], stay)

    expect(request).to have_been_made
    expect(quotes).to contain_exactly(
      Prices::Quote.new(listing_id: booking.id, total_cents: 42_050, currency: "EUR"),
      Prices::Quote.new(listing_id: expedia.id, total_cents: 39_900, currency: "EUR")
    )
  end

  it "ignores unknown prices and places that are not the property" do
    stub_request(:get, /api\.stay22\.com/).to_return(respond_with([
      accommodation(name: "Riva Hotel", lat: 43.3, lng: 17.02, suppliers: { "booking" => nil, "expedia" => 380 }),
      # 150 m away with another name: a neighbour, not this property.
      accommodation(name: "Villa Marija", lat: 43.30135, lng: 17.02, suppliers: { "booking" => 100 })
    ]))

    expect(provider.quotes_for([ booking, expedia ], stay).map(&:listing_id)).to eq([ expedia.id ])
  end

  it "takes a result a little further off when the name matches" do
    stub_request(:get, /api\.stay22\.com/).to_return(respond_with([
      accommodation(name: "Hotel Riva Makarska", lat: 43.30135, lng: 17.02, suppliers: { "booking" => 300 })
    ]))

    expect(provider.quotes_for([ booking ], stay).map(&:total_cents)).to eq([ 30_000 ])
  end

  it "uses no prices when Stay22 answers in another currency" do
    stub_request(:get, /api\.stay22\.com/).to_return(respond_with([
      accommodation(name: "Hotel Riva", lat: 43.3, lng: 17.02, suppliers: { "booking" => 300 })
    ], currency: "USD"))

    expect(provider.quotes_for([ booking ], stay)).to be_empty
  end

  it "searches a busy destination's whole area page by page" do
    others = Array.new(5) { |i| create(:listing, property: create(:property, destination:, latitude: 43.31 + i * 0.001, longitude: 17.05)) }
    first = stub_request(:get, /api\.stay22\.com/).with(query: hash_including("nelat" => "43.35", "swlng" => "16.95", "page" => "1"))
      .to_return(respond_with([ accommodation(name: "Riva", lat: 43.3, lng: 17.02, suppliers: { "booking" => 250 }) ], more: true))
    second = stub_request(:get, /api\.stay22\.com/).with(query: hash_including("page" => "2"))
      .to_return(respond_with([ accommodation(name: "X", lat: 43.31, lng: 17.05, suppliers: { "booking" => 90 }) ]))

    quotes = provider.quotes_for([ booking, *others ], stay)

    expect([ first, second ]).to all(have_been_made.once)
    expect(quotes.to_h { |quote| [ quote.listing_id, quote.total_cents ] }).to eq(booking.id => 25_000, others.first.id => 9_000)
  end

  it "fails loudly on an API error so the refresher can log it" do
    stub_request(:get, /api\.stay22\.com/).to_return(status: 429, body: '{"code":"RATE_LIMIT_EXCEEDED"}')

    expect { provider.quotes_for([ booking ], stay) }.to raise_error(/Stay22 API 429/)
  end

  it "keeps prices for less than the hour Stay22 allows" do
    expect(provider.ttl).to be < 1.hour
  end
end
