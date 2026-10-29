require "rails_helper"

RSpec.describe Osm::DestinationImport do
  let(:destination) { create(:destination, south: 43.28, west: 16.98, north: 43.32, east: 17.04) }

  it "imports every layer and classifies the properties" do
    counts = described_class.new(destination, client: FakeOverpassClient.new).call

    expect(counts).to eq(coastline: 1, inland_water: 1, beaches: 1, roads: 3, accommodations: 2)

    hotel = Property.find_by!(osm_id: 501)
    expect(hotel).to have_attributes(waterfront_category: "direct", crosses_promenade: true, crosses_road: false,
                                     beach_surface: "sand")
    expect(hotel.distance_to_water_m).to be_within(2).of(100)

    apartments = Property.find_by!(osm_id: 502)
    expect(apartments).to have_attributes(waterfront_category: "walkable", crosses_road: true)
  end
end
