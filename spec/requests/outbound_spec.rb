require "rails_helper"

RSpec.describe "Outbound clicks" do
  let(:listing) { create(:listing, url: "https://www.booking.com/hotel/hr/sample.html") }
  let(:check_in) { Date.current + 30 }

  it "logs the click and redirects with the stay filled in" do
    expect {
      get outbound_path(listing, check_in: check_in.iso8601, check_out: (check_in + 3).iso8601, adults: 2),
          headers: { "Referer" => "http://www.example.com/destinations/makarska?sort=price" }
    }.to change(OutboundClick, :count).by(1)

    expect(response).to have_http_status(:found)
    expect(response.location).to start_with("https://www.booking.com/hotel/hr/sample.html?")
    expect(response.location).to include("checkin=#{check_in.iso8601}")
    expect(response.headers["X-Robots-Tag"]).to include("noindex")

    click = OutboundClick.last
    expect(click).to have_attributes(listing:, property: listing.property, provider: "booking", check_in:,
                                     adults: 2, source_path: "/destinations/makarska")
  end

  it "passes children and their ages on" do
    get outbound_path(listing, check_in: check_in.iso8601, check_out: (check_in + 3).iso8601, adults: 2,
                               children: 1, child_ages: [ 7 ])

    expect(response.location).to include("group_children=1", "age=7")
    expect(OutboundClick.last.children).to eq(1)
  end

  it "redirects without dates when none are given" do
    get outbound_path(listing)

    expect(response.location).to eq("https://www.booking.com/hotel/hr/sample.html")
    expect(OutboundClick.last.check_in).to be_nil
  end

  it "does not record foreign referers" do
    get outbound_path(listing), headers: { "Referer" => "https://elsewhere.example/page" }

    expect(OutboundClick.last.source_path).to be_nil
  end

  it "returns 404 for inactive listings" do
    listing.update!(active: false)

    get outbound_path(listing)

    expect(response).to have_http_status(:not_found)
  end
end
