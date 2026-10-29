require "rails_helper"

RSpec.describe Osm::DestinationImport do
  let(:destination) { create(:destination, south: 43.28, west: 16.98, north: 43.32, east: 17.04) }

  it "imports every layer and classifies the properties" do
    counts = described_class.new(destination, client: FakeOverpassClient.new).call

    expect(counts).to eq(coastline: 1, inland_water: 1, beaches: 1, roads: 3, accommodations: 2, measurement_failures: 0)

    hotel = Property.find_by!(osm_id: 501)
    expect(hotel).to have_attributes(waterfront_category: "direct", crosses_promenade: true, crosses_road: false,
                                     beach_surface: "sand")
    expect(hotel.distance_to_water_m).to be_within(2).of(100)

    apartments = Property.find_by!(osm_id: 502)
    expect(apartments).to have_attributes(waterfront_category: "walkable", crosses_road: true)
  end

  it "keeps measuring the other properties when one fails" do
    real = Waterfront::Classification.instance_method(:call)
    allow_any_instance_of(Waterfront::Classification).to receive(:call) do |classification|
      property = classification.instance_variable_get(:@property)
      raise ActiveRecord::StatementInvalid, "lwgeom error" if property.osm_id == 501

      real.bind_call(classification)
    end

    counts = described_class.new(destination, client: FakeOverpassClient.new).call

    expect(counts[:measurement_failures]).to eq(1)
    expect(Property.find_by!(osm_id: 502).waterfront_category).to eq("walkable")
  end
end
