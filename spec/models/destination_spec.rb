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
end
