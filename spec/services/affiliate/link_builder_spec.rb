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
