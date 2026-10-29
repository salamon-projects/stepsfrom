require "rails_helper"

RSpec.describe Waterfront::Classifier do
  let(:classifier) { described_class.new }

  def measurement(**attrs)
    defaults = Waterfront::Measurement.members.index_with(nil).merge(
      water_data_available: true, crosses_road: false, crosses_promenade: false, crosses_beach: false
    )
    Waterfront::Measurement.new(**defaults.merge(attrs))
  end

  it "is unknown without imported water data" do
    expect(classifier.category_for(measurement(water_data_available: false))).to eq("unknown")
  end

  it "is not waterfront without water nearby or beyond walking distance" do
    expect(classifier.category_for(measurement(distance_to_water_m: nil))).to eq("not_waterfront")
    expect(classifier.category_for(measurement(distance_to_water_m: 301))).to eq("not_waterfront")
  end

  it "is direct close to the water with no road between" do
    expect(classifier.category_for(measurement(distance_to_water_m: 50))).to eq("direct")
    expect(classifier.category_for(measurement(distance_to_water_m: 50, crosses_promenade: true))).to eq("direct")
  end

  it "is only near when a road or railway lies between" do
    expect(classifier.category_for(measurement(distance_to_water_m: 15, crosses_road: true))).to eq("near")
  end

  it "is direct on a wide beach the property touches" do
    wide_beach = measurement(distance_to_water_m: 140, crosses_beach: true, distance_to_beach_m: 5)

    expect(classifier.category_for(wide_beach)).to eq("direct")
    expect(classifier.category_for(wide_beach.with(distance_to_beach_m: 40))).to eq("walkable")
    expect(classifier.category_for(wide_beach.with(crosses_beach: false))).to eq("walkable")
    expect(classifier.category_for(wide_beach.with(distance_to_water_m: 160))).to eq("walkable")
  end

  it "uses near and walkable bands" do
    expect(classifier.category_for(measurement(distance_to_water_m: 100))).to eq("near")
    expect(classifier.category_for(measurement(distance_to_water_m: 300))).to eq("walkable")
  end
end
