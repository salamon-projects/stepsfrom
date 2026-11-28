require "rails_helper"
require Rails.root.join("db/migrate/20261128140000_give_brac_its_island_area")

# Brač's area is the island, not the rectangle around it, which also covers
# the mainland Omiš Riviera. Mainland properties assigned to Brač stay in
# admin and leave every public page.
RSpec.describe "Brač's island area" do
  let(:brac) { create(:destination, :brac) }

  it "lists the island's stays and none of the mainland's, though all are assigned to Brač" do
    island = BracHelpers::ISLAND.map { |place| brac_property(place, destination: brac) }
    mainland = BracHelpers::MAINLAND.map { |place| brac_property(place, destination: brac) }

    expect(Property.published).to match_array(island)
    expect(Property.outside_destination_area).to match_array(mainland)
    expect(BracHelpers::ISLAND.map { |place| brac.covers?(brac_point(place)) }).to all(be(true))
    expect(BracHelpers::MAINLAND.map { |place| brac.covers?(brac_point(place)) }).to all(be(false))
  end

  it "shows island stays on the destination page and leaves out mainland ones" do
    brac_property(:bol, destination: brac, name: "Bol Beach Hotel")
    brac_property(:supetar, destination: brac, name: "Supetar Rooms")
    brac_property(:povlja, destination: brac, name: "Povlja Apartments")
    pisak = brac_property(:pisak, destination: brac, name: "Apartments Pisak")
    brac_property(:mala_luka, destination: brac, name: "Mala Luka Rooms")
    brac_property(:sagitta, destination: brac, name: "Sagitta Village")

    get destination_path(brac)
    expect(response.body).to include("Bol Beach Hotel", "Supetar Rooms", "Povlja Apartments")
    expect(response.body).not_to include("Apartments Pisak", "Mala Luka Rooms", "Sagitta Village")

    get property_path(pisak)
    expect(response).to have_http_status(:not_found)
  end

  it "keeps the old rectangle's box for Overpass, up to the island's north edge" do
    expect(brac).not_to be_rectangular
    expect(brac.bbox).to eq([ 43.25, 16.38, 43.405, 16.90 ])
  end

  it "only adds island properties on import, though Overpass returns the mainland too" do
    elements = BracHelpers::PLACES.each_with_index.map do |(_place, (lat, lon)), id|
      Osm::Element.from_json("type" => "node", "id" => id + 1, "lat" => lat, "lon" => lon,
                             "tags" => { "tourism" => "hotel", "name" => "Hotel #{id + 1}" })
    end

    count = Osm::Importers::Accommodations.new(brac, client: instance_double(Osm::OverpassClient, query: elements)).call

    expect(count).to eq(BracHelpers::ISLAND.size)
  end

  describe "the migration" do
    let!(:destination) { create(:destination, name: "Brač", south: 43.25, west: 16.38, north: 43.42, east: 16.90) }

    around do |example|
      verbose = ActiveRecord::Migration.verbose
      ActiveRecord::Migration.verbose = false
      example.run
    ensure
      ActiveRecord::Migration.verbose = verbose
    end

    it "sets the island polygon, and the rectangle back on the way down" do
      bol = brac_property(:bol, destination:)
      pisak = brac_property(:pisak, destination:)
      expect(destination.slug).to eq("brac")
      expect(Property.published).to contain_exactly(bol, pisak)

      GiveBracItsIslandArea.new.migrate(:up)
      expect(Destination.find(destination.id).area).to eq(Destination.configured_area("brac"))
      expect(Property.published).to contain_exactly(bol)

      GiveBracItsIslandArea.new.migrate(:down)
      expect(Destination.find(destination.id)).to be_rectangular
      expect(Destination.find(destination.id).bbox).to eq([ 43.25, 16.38, 43.42, 16.90 ])
      expect(Property.published).to contain_exactly(bol, pisak)
    end
  end
end
