require "rails_helper"

RSpec.describe ClassifyPropertyJob do
  it "classifies the property" do
    property = create(:property)
    create(:water_feature, geom: east_west_line(north_m: 20))

    described_class.perform_now(property.id)

    expect(property.reload.waterfront_category).to eq("direct")
  end

  it "ignores deleted properties" do
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end
