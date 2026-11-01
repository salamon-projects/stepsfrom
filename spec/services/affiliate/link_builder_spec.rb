require "rails_helper"

RSpec.describe Affiliate::LinkBuilder do
  let(:stay) { Stay.new(check_in: Date.new(2027, 7, 1), check_out: Date.new(2027, 7, 8), adults: 3) }

  before { travel_to Date.new(2027, 1, 1) }

  it "links to the listing as-is without a stay" do
    listing = build(:listing, url: "https://www.booking.com/hotel/hr/sample.html?lang=en")

    expect(described_class.new(listing).url).to eq("https://www.booking.com/hotel/hr/sample.html?lang=en")
  end

  it "fills in Booking.com stay parameters, replacing any already in the URL" do
    listing = build(:listing, url: "https://www.booking.com/hotel/hr/sample.html?lang=en&checkin=2020-01-01")

    uri = URI.parse(described_class.new(listing, stay).url)
    expect(Rack::Utils.parse_query(uri.query)).to eq(
      "lang" => "en", "checkin" => "2027-07-01", "checkout" => "2027-07-08",
      "group_adults" => "3", "group_children" => "0", "no_rooms" => "1"
    )
  end

  it "uses each provider's own parameter format" do
    listing = build(:listing, :agoda, url: "https://www.agoda.com/sample/hotel/makarska-hr.html")

    query = Rack::Utils.parse_query(URI.parse(described_class.new(listing, stay).url).query)
    expect(query).to include("checkIn" => "2027-07-01", "los" => "7", "adults" => "3")
  end

  context "with children" do
    let(:stay) do
      Stay.new(check_in: Date.new(2027, 7, 1), check_out: Date.new(2027, 7, 8), adults: 2, children: 2, child_ages: [ 5, 8 ])
    end

    def query_for(listing)
      URI.decode_www_form(URI.parse(described_class.new(listing, stay).url).query)
    end

    it "gives Booking.com the count and one age parameter per child" do
      query = query_for(build(:listing, url: "https://www.booking.com/hotel/hr/sample.html?age=3"))

      expect(query).to include([ "group_children", "2" ])
      expect(query.select { |key, _| key == "age" }).to eq([ [ "age", "5" ], [ "age", "8" ] ])
    end

    it "writes the ages in each provider's format" do
      expedia = build(:listing, :expedia, url: "https://www.expedia.com/Makarska-Hotels-Sample.h1.Hotel-Information")
      vrbo = build(:listing, :vrbo, url: "https://www.vrbo.com/1234567")
      agoda = build(:listing, :agoda, url: "https://www.agoda.com/sample/hotel/makarska-hr.html")

      expect(query_for(expedia)).to include([ "rm1", "a2:c5:c8" ])
      expect(query_for(vrbo)).to include([ "children", "1_5,1_8" ])
      expect(query_for(agoda)).to include([ "children", "2" ], [ "childages", "5,8" ])
    end
  end

  it "leaves out child parameters without children" do
    listing = build(:listing, :vrbo, url: "https://www.vrbo.com/1234567")

    expect(Rack::Utils.parse_query(URI.parse(described_class.new(listing, stay).url).query)).not_to have_key("children")
  end

  it "ignores an invalid stay" do
    listing = build(:listing, url: "https://www.booking.com/hotel/hr/sample.html")
    invalid = Stay.new(check_in: Date.new(2027, 7, 8), check_out: Date.new(2027, 7, 1))

    expect(described_class.new(listing, invalid).url).to eq("https://www.booking.com/hotel/hr/sample.html")
  end

  it "wraps the target in the configured tracking URL" do
    listing = build(:listing, url: "https://www.booking.com/hotel/hr/sample.html")
    stub_const("ENV", ENV.to_h.merge("BOOKING_TRACKING_URL" => "https://www.anrdoezrs.net/click-1-2?url={url}"))

    url = described_class.new(listing, stay).url
    expect(url).to start_with("https://www.anrdoezrs.net/click-1-2?url=https%3A%2F%2Fwww.booking.com%2Fhotel%2Fhr%2Fsample.html%3F")
    expect(CGI.unescape(url.split("url=", 2).last)).to include("checkin=2027-07-01")
  end
end
