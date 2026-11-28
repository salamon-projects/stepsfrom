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

  it "leaves rivers out" do
    river = Osm::Element.from_json("type" => "way", "id" => 9, "tags" => { "natural" => "water", "water" => "river" },
                                   "geometry" => [ [ 17.0, 43.3 ], [ 17.01, 43.3 ], [ 17.01, 43.31 ], [ 17.0, 43.3 ] ].map { |lon, lat| { "lon" => lon, "lat" => lat } })

    expect(Osm::Importers::InlandWater.new(destination, client: instance_double(Osm::OverpassClient, query: [ river ])).call).to eq(0)
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

  describe "features OSM no longer has" do
    # The box's north edge is 2,224 m north of the base point.
    it "removes them inside the box, but keeps those near its edge or outside it" do
      create(:road_segment, osm_id: 990, geom: east_west_line(north_m: 500))
      create(:road_segment, osm_id: 991, geom: east_west_line(north_m: 2_180))
      create(:road_segment, osm_id: 992, geom: east_west_line(north_m: 3_000))

      importer = Osm::Importers::Roads.new(destination, client:)
      importer.call

      expect(importer.removed).to eq(1)
      expect(RoadSegment.pluck(:osm_id)).to contain_exactly(401, 402, 403, 991, 992)
    end

    it "keeps what a layer returns again" do
      run(Osm::Importers::Roads)
      run(Osm::Importers::Roads)

      expect(RoadSegment.count).to eq(3)
    end

    it "only removes the features of its own layer" do
      create(:water_feature, osm_id: 990, kind: "sea", geom: east_west_line(north_m: 500))
      create(:water_feature, osm_id: 991, kind: "lake", geom: box(south_m: 600, north_m: 700))

      run(Osm::Importers::Coastline)

      expect(WaterFeature.pluck(:osm_id)).to contain_exactly(101, 991)
    end

    it "removes nothing when a layer comes back empty" do
      create(:beach, geom: box(south_m: 600, north_m: 700))
      empty = instance_double(Osm::OverpassClient, query: [])

      Osm::Importers::Beaches.new(destination, client: empty).call

      expect(Beach.count).to eq(1)
    end
  end

  describe Osm::Importers::Accommodations do
    it "creates pending properties from named nodes and ways" do
      expect(run(described_class)).to eq(2)

      hotel = Property.find_by!(osm_type: "node", osm_id: 501)
      expect(hotel).to have_attributes(name: "Hotel Sample Bay", kind: "hotel", stars: 4,
                                       address: "Obala 1, Sampleville", website: "https://hotel-sample-bay.example",
                                       destination:)
      expect(hotel.footprint).to be_nil
      expect(hotel).not_to be_reviewed

      apartments = Property.find_by!(osm_type: "way", osm_id: 502)
      expect(apartments).to have_attributes(kind: "apartment", website: nil)
      expect(apartments.footprint).to be_present
      expect(apartments.lonlat.x).to be_within(1e-6).of(17.0280)
    end

    it "still imports campsites, which stay in the database but off the site" do
      element = Osm::Element.from_json("type" => "node", "id" => 601, "lat" => 43.3, "lon" => 17.0,
                                       "tags" => { "tourism" => "camp_site", "name" => "Kamp Sample" })

      2.times { described_class.new(destination, client: instance_double(Osm::OverpassClient, query: [ element ])).call }

      camp = Property.sole
      expect(camp).to have_attributes(name: "Kamp Sample", kind: "camp_site", osm_missing_since: nil, destination:)
      expect(camp).to be_excluded_kind
    end

    it "keeps the geometry and name of reviewed properties on re-import" do
      run(described_class)
      hotel = Property.find_by!(osm_id: 501)
      hotel.update!(name: "Hotel Sample Bay & Spa", latitude: 43.3002, longitude: 17.0201, reviewed_at: Time.current)

      run(described_class)

      expect(hotel.reload).to have_attributes(name: "Hotel Sample Bay & Spa", latitude: 43.3002)
    end

    it "keeps details edited on reviewed properties and only fills blanks" do
      run(described_class)
      hotel = Property.find_by!(osm_id: 501)
      hotel.update!(address: "Obala 1a, Sampleville", stars: nil, reviewed_at: Time.current)

      run(described_class)

      expect(hotel.reload).to have_attributes(address: "Obala 1a, Sampleville", stars: 4)
    end

    it "updates the name of properties still pending review" do
      run(described_class)
      Property.find_by!(osm_id: 501).update!(name: "Old name")

      run(described_class)

      expect(Property.find_by!(osm_id: 501).name).to eq("Hotel Sample Bay")
    end

    it "flags properties OSM no longer returns, and clears the flag when they are back" do
      run(described_class)
      gone = create(:property, :direct, destination:, osm_type: "node", osm_id: 599, lonlat: point_at(north_m: 300))
      manual = create(:property, destination:, lonlat: point_at(north_m: 300))
      elsewhere = create(:property, destination:, osm_type: "node", osm_id: 598, lonlat: point_at(north_m: 3_000))

      travel_to Time.zone.local(2026, 11, 2, 3, 0) do
        run(described_class)
      end

      expect(gone.reload.osm_missing_since).to eq(Time.zone.local(2026, 11, 2, 3, 0))
      expect(Property.missing_from_osm).to contain_exactly(gone)
      expect(gone).not_to be_listed
      expect([ manual, elsewhere ].map { |property| property.reload.osm_missing_since }).to all(be_nil)

      run(described_class)
      expect(gone.reload.osm_missing_since).to eq(Time.zone.local(2026, 11, 2, 3, 0))

      hotel = Property.find_by!(osm_id: 501)
      hotel.update_columns(osm_missing_since: 1.day.ago)
      run(described_class)
      expect(hotel.reload.osm_missing_since).to be_nil
    end

    context "for a destination whose area is not a rectangle" do
      let(:kassandra) { create(:destination, :kassandra) }

      def hotel_at(id, place)
        lat, lon = KassandraHelpers::PLACES.fetch(place)
        Osm::Element.from_json("type" => "node", "id" => id, "lat" => lat, "lon" => lon,
                               "tags" => { "tourism" => "hotel", "name" => "Hotel #{id}" })
      end

      it "adds only the properties inside the area, though Overpass returns the whole box" do
        elements = [ hotel_at(1, :kallithea), hotel_at(2, :istion_club), hotel_at(3, :anthemus_sea) ]

        count = described_class.new(kassandra, client: instance_double(Osm::OverpassClient, query: elements)).call

        expect(count).to eq(2)
        expect(Property.pluck(:osm_id)).to contain_exactly(1, 2)
        expect(Property.all.map(&:destination)).to all(eq(kassandra))
      end

      it "keeps updating a property assigned before the area was narrowed, without listing it" do
        old = kassandra_property(:anthemus_sea, destination: kassandra, osm_type: "node", osm_id: 3)

        described_class.new(kassandra, client: instance_double(Osm::OverpassClient, query: [ hotel_at(3, :anthemus_sea) ])).call

        expect(old.reload).to have_attributes(name: "Hotel 3", osm_missing_since: nil, destination: kassandra)
        expect(old).not_to be_listed
      end
    end

    it "flags nothing when the query comes back empty" do
      run(described_class)

      described_class.new(destination, client: instance_double(Osm::OverpassClient, query: [])).call

      expect(Property.missing_from_osm).to be_empty
    end

    it "uses the English name of a property named in another script" do
      element = ->(id, tags) { Osm::Element.from_json("type" => "node", "id" => id, "lat" => 43.3, "lon" => 17.0, "tags" => tags) }
      elements = [
        element.call(1, { "tourism" => "camp_site", "name" => "Κάμπινγκ Μαρμαρά", "name:en" => "Camping Marmara" }),
        element.call(2, { "tourism" => "hotel", "name" => "Ξενοδοχείο Ήλιος", "int_name" => "Hotel Ilios" }),
        element.call(3, { "tourism" => "hotel", "name" => "Βίλα Ρόδων" }),
        element.call(4, { "tourism" => "hotel", "name" => "Hôtel Les Pins", "name:en" => "Pines Hotel" })
      ]

      described_class.new(destination, client: instance_double(Osm::OverpassClient, query: elements)).call

      expect(Property.order(:osm_id).pluck(:name, :local_name)).to eq([
        [ "Camping Marmara", "Κάμπινγκ Μαρμαρά" ], [ "Hotel Ilios", "Ξενοδοχείο Ήλιος" ],
        [ "Vila Rodon", "Βίλα Ρόδων" ], [ "Hôtel Les Pins", nil ]
      ])
    end

    it "keeps OSM's tags and last edit without moving updated_at when only they change" do
      json = { "type" => "node", "id" => 701, "lat" => 43.3, "lon" => 17.0, "timestamp" => "2026-03-04T05:06:07Z",
               "version" => 7, "tags" => { "tourism" => "hotel", "name" => "Hotel Mare", "rooms" => "12" } }
      import = ->(attrs) { described_class.new(destination, client: instance_double(Osm::OverpassClient, query: [ Osm::Element.from_json(json.merge(attrs)) ])).call }

      import.call({})
      hotel = Property.sole
      expect(hotel).to have_attributes(osm_version: 7, osm_tags: include("rooms" => "12"),
                                       osm_timestamp: Time.utc(2026, 3, 4, 5, 6, 7))

      hotel.update_columns(updated_at: 2.days.ago)
      import.call("version" => 8, "tags" => json["tags"].merge("rooms" => "14"))
      expect(hotel.reload).to have_attributes(osm_version: 8, osm_tags: include("rooms" => "14"))
      expect(hotel.updated_at).to be < 1.day.ago
    end

    it "asks Overpass for each element's last edit" do
      described_class.new(destination, client:).call

      expect(client.queries.last).to end_with("out geom meta;")
    end

    it "keeps a place that is mainly something else off the site until an admin approves it" do
      element = Osm::Element.from_json("type" => "node", "id" => 801, "lat" => 43.3, "lon" => 17.02,
                                       "tags" => { "tourism" => "guest_house", "amenity" => "dive_centre", "name" => "Diving Hvar" })
      create(:water_feature, geom: east_west_line(north_m: 10))
      create(:beach, geom: box(south_m: 0, north_m: 10))

      described_class.new(destination, client: instance_double(Osm::OverpassClient, query: [ element ])).call
      diving = Property.sole
      Waterfront::Classification.new(diving).call

      expect(diving.reload.non_lodging_tag).to eq("amenity=dive_centre")
      expect(Property.published).to be_empty
      expect(Property.needing_review).to eq([ diving ])

      diving.update!(reviewed_at: Time.current)
      expect(Property.published).to eq([ diving ])
    end

    it "does not count a hotel's own restaurant as something else" do
      element = Osm::Element.from_json("type" => "node", "id" => 802, "lat" => 43.3, "lon" => 17.02,
                                       "tags" => { "tourism" => "hotel", "amenity" => "restaurant", "name" => "Hotel Konoba" })

      described_class.new(destination, client: instance_double(Osm::OverpassClient, query: [ element ])).call

      expect(Property.sole.non_lodging_tag).to be_nil
    end

    it "lists a place mapped twice once, keeping the one with a building outline" do
      lon, lat = offset
      node = Osm::Element.from_json("type" => "node", "id" => 901, "lat" => lat, "lon" => lon,
                                    "tags" => { "tourism" => "hotel", "name" => "Hotel Dalmacija" })
      ring = [ offset(north_m: -10, east_m: -10), offset(north_m: -10, east_m: 10), offset(north_m: 10, east_m: 10),
               offset(north_m: 10, east_m: -10), offset(north_m: -10, east_m: -10) ]
      way = Osm::Element.from_json("type" => "way", "id" => 902, "tags" => { "tourism" => "hotel", "name" => "Dalmacija" },
                                   "geometry" => ring.map { |x, y| { "lon" => x, "lat" => y } })
      same_name = Osm::Element.from_json("type" => "node", "id" => 903, "lat" => lat, "lon" => lon,
                                         "tags" => { "tourism" => "hotel", "name" => "Hotel Dalmacija" })
      far_lon, far_lat = offset(north_m: 500)
      far = Osm::Element.from_json("type" => "node", "id" => 904, "lat" => far_lat, "lon" => far_lon,
                                   "tags" => { "tourism" => "hotel", "name" => "Hotel Dalmacija" })
      import = ->(elements) { described_class.new(destination, client: instance_double(Osm::OverpassClient, query: elements)).call }

      import.call([ node, same_name, far ])
      first, second, distant = Property.order(:osm_id).to_a
      expect([ first, second, distant ].map { |p| p.reload.duplicate_of_id }).to eq([ nil, first.id, nil ])

      import.call([ node, way, same_name, far ])
      outlined = Property.find_by!(osm_id: 902)
      expect([ first, second, outlined, distant ].map { |p| p.reload.duplicate_of_id }).to eq([ outlined.id, outlined.id, nil, nil ])

      second.update!(reviewed_at: Time.current, duplicate_of: nil)
      import.call([ node, way, same_name, far ])
      expect(second.reload.duplicate_of_id).to be_nil
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
