require "rails_helper"

RSpec.describe Listing do
  it "accepts a URL on the provider's domain" do
    expect(build(:listing, provider: "booking", url: "https://www.booking.com/hotel/hr/x.html")).to be_valid
    expect(build(:listing, provider: "expedia", url: "https://www.expedia.co.uk/x.Hotel-Information")).to be_valid
  end

  it "rejects a URL on another domain" do
    listing = build(:listing, provider: "booking", url: "https://www.booking.com.evil.example/hotel")

    expect(listing).not_to be_valid
    expect(listing.errors[:url]).to include("is not a Booking.com address")
  end

  it "allows one listing per provider and property" do
    listing = create(:listing)

    expect(build(:listing, property: listing.property)).not_to be_valid
  end

  it "reclassifies the property when the reported coordinates change" do
    listing = create(:listing)

    expect {
      listing.update!(reported_latitude: 43.3, reported_longitude: 17.0)
    }.to have_enqueued_job(ClassifyPropertyJob).with(listing.property_id)
    expect(listing.reload.reported_lonlat.y).to be_within(1e-9).of(43.3)
  end

  it "clears the reported coordinates when both are blanked" do
    listing = create(:listing, reported_latitude: 43.3, reported_longitude: 17.0)

    listing.update!(reported_latitude: "", reported_longitude: "")

    expect(listing.reload.reported_lonlat).to be_nil
  end
end
