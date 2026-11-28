require "rails_helper"

RSpec.describe Property do
  it "builds lonlat from latitude and longitude" do
    property = create(:property, latitude: 43.3, longitude: 17.02)

    reloaded = described_class.find(property.id)
    expect(reloaded.lonlat.y).to be_within(1e-9).of(43.3)
    expect(reloaded.longitude).to be_within(1e-9).of(17.02)
  end

  it "queues a classification when the coordinates change" do
    property = create(:property)

    expect { property.update!(latitude: 43.31) }.to have_enqueued_job(ClassifyPropertyJob).with(property.id)
    expect { property.update!(name: "Renamed") }.not_to have_enqueued_job(ClassifyPropertyJob)
  end

  describe ".published" do
    it "lists properties measured on the waterfront" do
      waterfront = create(:property, :walkable)
      create(:property, :not_waterfront)
      create(:property) # not measured yet
      create(:property, :direct, :hidden)
      create(:property, :direct, osm_missing_since: 1.day.ago)

      expect(described_class.published).to contain_exactly(waterfront)
      expect(waterfront).to be_listed
      expect(create(:property, :direct, :hidden)).not_to be_listed
    end

    it "leaves out the kinds kept off the site, but keeps hostels" do
      camp = create(:property, :direct, kind: "camp_site")
      hostel = create(:property, :direct, kind: "hostel")

      expect(described_class.excluded_kinds).to eq(%w[camp_site])
      expect(described_class.published).to contain_exactly(hostel)
      expect(camp).not_to be_listed
      expect(camp).to be_excluded_kind
      expect(described_class.all).to include(camp)
    end

    it "lists every kind again when the exclusion list is emptied" do
      camp = create(:property, :direct, kind: "camp_site")
      allow(described_class).to receive(:excluded_kinds).and_return([])

      expect(described_class.published).to contain_exactly(camp)
      expect(described_class.public_kinds).to eq(described_class::KINDS)
    end
  end

  describe "outside its destination's area" do
    let(:kassandra) { create(:destination, :kassandra) }

    it "lists only properties inside the area, even when assigned to the destination" do
      inside = %i[kallithea istion_club].map { |place| kassandra_property(place, destination: kassandra) }
      outside = %i[porto_carras vourvourou anthemus_sea].map { |place| kassandra_property(place, destination: kassandra) }

      expect(described_class.published).to match_array(inside)
      expect(kassandra.properties.published).to match_array(inside)
      expect(described_class.outside_destination_area).to match_array(outside)
      expect(outside).to all(be_outside_destination_area)
      expect(outside.map(&:listed?)).to all(be(false))
    end

    it "lists properties anywhere in a rectangular destination's box, edges included" do
      destination = create(:destination, south: 43.25, west: 16.95, north: 43.35, east: 17.10)
      corner = create(:property, :direct, destination:, latitude: 43.25, longitude: 17.10)
      south_edge = create(:property, :direct, destination:, latitude: 43.2501, longitude: 17.025)

      expect(described_class.published).to contain_exactly(corner, south_edge)
    end
  end

  describe ".by_waterfront" do
    it "orders by category, then distance" do
      walkable = create(:property, :walkable)
      far_direct = create(:property, :direct, distance_to_water_m: 40)
      close_direct = create(:property, :direct, distance_to_water_m: 10)
      near = create(:property, :near)

      expect(described_class.by_waterfront).to eq([ close_direct, far_direct, near, walkable ])
    end
  end

  describe ".beachfront_claim_conflicts" do
    it "finds properties an OTA calls beachfront that we measured far from the water" do
      conflict = create(:property, :not_waterfront)
      create(:listing, property: conflict, claims_beachfront: true)
      fine = create(:property, :direct)
      create(:listing, property: fine, claims_beachfront: true)

      expect(described_class.beachfront_claim_conflicts).to contain_exactly(conflict)
    end
  end
end
