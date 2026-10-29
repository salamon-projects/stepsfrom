require "rails_helper"

RSpec.describe "OSM importers" do
  let(:destination) { create(:destination, south: 43.28, west: 16.98, north: 43.32, east: 17.04) }
  let(:client) { FakeOverpassClient.new }

  def run(importer)
    importer.new(destination, client:).call
  end

  it "queries the destination's bounding box" do
    run(Osm::Importers::Coastline)

    expect(client.queries.last).to include('way["natural"="coastline"](43.28,16.98,43.32,17.04);').and include("out geom;")
  end

  it "imports coastline ways as sea and skips degenerate ones" do
    expect(run(Osm::Importers::Coastline)).to eq(1)

    feature = WaterFeature.sole
    expect(feature).to have_attributes(kind: "sea", osm_type: "way", osm_id: 101)
    expect(feature.geom.num_points).to eq(3)
  end

  it "is idempotent" do
    2.times { run(Osm::Importers::Coastline) }

    expect(WaterFeature.count).to eq(1)
  end

  it "imports closed lake polygons" do
    expect(run(Osm::Importers::InlandWater)).to eq(1)
    expect(WaterFeature.sole).to have_attributes(kind: "lake", name: "Test Lake")
  end

  it "imports beaches with a normalised surface" do
    run(Osm::Importers::Beaches)

    expect(Beach.sole).to have_attributes(name: "Sample Beach", surface: "sand")
  end

  it "categorises roads, skipping tunnels and parking aisles" do
    expect(run(Osm::Importers::Roads)).to eq(3)

    expect(RoadSegment.pluck(:osm_id, :category)).to contain_exactly([ 401, "road" ], [ 402, "promenade" ], [ 403, "rail" ])
  end

  describe Osm::Importers::Accommodations do
    it "creates pending properties from named nodes and ways" do
      expect(run(described_class)).to eq(2)

      hotel = Property.find_by!(osm_type: "node", osm_id: 501)
      expect(hotel).to have_attributes(name: "Hotel Sample Bay", kind: "hotel", stars: 4, qa_status: "pending",
                                       address: "Obala 1, Sampleville", website: "https://hotel-sample-bay.example",
                                       destination:)
      expect(hotel.footprint).to be_nil

      apartments = Property.find_by!(osm_type: "way", osm_id: 502)
      expect(apartments).to have_attributes(kind: "apartment", website: nil)
      expect(apartments.footprint).to be_present
      expect(apartments.lonlat.x).to be_within(1e-6).of(17.0280)
    end

    it "keeps the geometry and name of reviewed properties on re-import" do
      run(described_class)
      hotel = Property.find_by!(osm_id: 501)
      hotel.update!(qa_status: "approved", name: "Hotel Sample Bay & Spa", latitude: 43.3002, longitude: 17.0201)

      run(described_class)

      expect(hotel.reload).to have_attributes(name: "Hotel Sample Bay & Spa", latitude: 43.3002)
    end

    it "updates the geometry of properties still pending review" do
      run(described_class)
      hotel = Property.find_by!(osm_id: 501)
      hotel.update!(latitude: 43.4, longitude: 17.0)

      run(described_class)

      expect(hotel.reload.latitude).to be_within(1e-9).of(43.30010)
    end
  end
end
