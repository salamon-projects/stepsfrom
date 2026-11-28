require "rails_helper"

RSpec.describe Affiliate::AutoListings do
  let(:destination) { create(:destination, name: "Makarska Riviera") }
  let!(:property) { create(:property, :direct, destination:, name: "Hotel Riva") }

  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  it "adds nothing while no programme is set up" do
    expect(described_class.new.call).to eq(created: 0, updated: 0, removed: 0)
    expect(Listing.count).to eq(0)
  end

  context "with a Stay22 affiliate id" do
    around { |example| with_env("STAY22_AID" => "stepsfrom", &example) }

    it "links each Stay22 site to the property by name and position" do
      expect(described_class.new.call).to include(created: 3)

      expect(property.listings.pluck(:provider)).to contain_exactly("booking", "expedia", "agoda")
      booking = property.listings.find_by(provider: "booking")
      expect(booking).to have_attributes(generator: "stay22", active: true)
      uri = URI.parse(booking.url)
      expect(uri.host).to eq("www.stay22.com")
      expect(uri.path).to eq("/allez/booking")
      expect(Rack::Utils.parse_query(uri.query)).to eq(
        "hotelname" => "Hotel Riva", "lat" => property.latitude.round(6).to_s, "lng" => property.longitude.round(6).to_s
      )
    end

    it "leaves listings an admin entered or switched off alone" do
      entered = create(:listing, property:, url: "https://www.booking.com/hotel/hr/riva.html")
      described_class.new.call
      property.listings.find_by(provider: "expedia").update!(active: false)

      property.update!(name: "Hotel Riva Makarska")
      counts = described_class.new.call

      expect(counts).to eq(created: 0, updated: 1, removed: 0)
      expect(entered.reload.url).to eq("https://www.booking.com/hotel/hr/riva.html")
      expect(property.listings.find_by(provider: "expedia")).not_to be_active
      expect(property.listings.find_by(provider: "agoda").url).to include("hotelname=Hotel+Riva+Makarska")
    end

    it "creates unconfirmed links, and a confirmed one needs checking again once its link changes" do
      described_class.new.call
      expect(property.listings).to all(have_attributes(confirmed_at: nil))

      booking = property.listings.find_by(provider: "booking")
      booking.confirm!
      described_class.new.call
      expect(booking.reload).to be_confirmed

      property.update!(name: "Hotel Riva Makarska")
      described_class.new.call
      expect(booking.reload).not_to be_confirmed
    end

    it "searches Booking.com itself once its own programme is set up" do
      described_class.new.call

      with_env("BOOKING_TRACKING_URL" => "https://www.awin1.com/cread.php?p={url}") { described_class.new.call }

      booking = property.listings.find_by(provider: "booking")
      expect(booking.generator).to eq("search")
      expect(booking.url).to eq("https://www.booking.com/searchresults.html?ss=Hotel+Riva%2C+Makarska+Riviera")
    end

    it "skips properties no longer in OpenStreetMap" do
      property.update_columns(osm_missing_since: Time.current)

      expect { described_class.new.call }.not_to change(Listing, :count)
    end
  end

  it "removes automatic listings when the programme is no longer set up, keeping switched-off ones" do
    with_env("STAY22_AID" => "stepsfrom") do
      described_class.new.call
      property.listings.find_by(provider: "agoda").update!(active: false)
    end

    expect(described_class.new.call).to include(removed: 2)
    expect(property.listings.pluck(:provider)).to eq([ "agoda" ])
  end
end
