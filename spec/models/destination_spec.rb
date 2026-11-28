require "rails_helper"

RSpec.describe Destination do
  it "builds its area and center from a bounding box" do
    destination = create(:destination, south: 43.0, west: 17.0, north: 43.2, east: 17.4)

    reloaded = described_class.find(destination.id)
    expect(reloaded.bbox).to eq([ 43.0, 17.0, 43.2, 17.4 ])
    expect(reloaded.center.y).to be_within(1e-9).of(43.1)
    expect(reloaded.center.x).to be_within(1e-9).of(17.2)
  end

  it "rejects an inverted bounding box" do
    destination = build(:destination, south: 43.2, north: 43.0)

    expect(destination).not_to be_valid
    expect(destination.errors[:north]).to be_present
  end

  it "generates a unique slug" do
    first = create(:destination, name: "Makarska Riviera")
    second = create(:destination, name: "Makarska Riviera")

    expect(first.slug).to eq("makarska-riviera")
    expect(second.slug).to eq("makarska-riviera-2")
    expect(first.to_param).to eq("makarska-riviera")
  end

  describe "an area that is not a rectangle" do
    let(:peninsula) { described_class.configured_area("kassandra") }

    it "takes its bounding box and center from the area" do
      destination = create(:destination, :kassandra)

      reloaded = described_class.find(destination.id)
      expect(reloaded.bbox).to eq([ 39.90, 23.28, 40.22, 23.78 ])
      expect(reloaded.center.x).to be_within(1e-9).of(23.53)
      expect(reloaded.center.y).to be_within(1e-9).of(40.06)
      expect(reloaded.area.exterior_ring.num_points).to eq(9)
    end

    it "keeps the area when saved without changing the bounding box" do
      destination = described_class.find(create(:destination, :kassandra).id)

      destination.update!(name: "Kassandra peninsula", south: "39.9", west: "23.28", north: "40.22", east: "23.78")

      expect(described_class.find(destination.id).area).to eq(peninsula)
    end

    it "becomes a rectangle again when the bounding box is changed" do
      destination = described_class.find(create(:destination, :kassandra).id)

      destination.update!(north: 40.25)

      reloaded = described_class.find(destination.id)
      expect(reloaded.area).to eq(Geo.bbox_polygon(south: 39.90, west: 23.28, north: 40.25, east: 23.78))
      expect(reloaded.center.y).to be_within(1e-9).of(40.075)
    end

    it "tells whether a point lies in it" do
      destination = create(:destination, :kassandra)

      expect(destination.covers?(kassandra_point(:kallithea))).to be(true)
      expect(destination.covers?(kassandra_point(:anthemus_sea))).to be(false)
    end
  end
end
