require "rails_helper"

RSpec.describe Stay do
  let(:check_in) { Date.current + 10 }

  it "is valid for future dates in order" do
    stay = described_class.new(check_in:, check_out: check_in + 3, adults: 2)

    expect(stay).to be_valid
    expect(stay.nights).to eq(3)
  end

  it "rejects past, reversed or overlong stays" do
    expect(described_class.new(check_in: Date.current - 1, check_out: Date.current + 1)).not_to be_valid
    expect(described_class.new(check_in:, check_out: check_in)).not_to be_valid
    expect(described_class.new(check_in:, check_out: check_in + 31)).not_to be_valid
  end

  describe ".from_params" do
    it "returns nil without dates" do
      expect(described_class.from_params(ActionController::Parameters.new(adults: "2"))).to be_nil
    end

    it "parses dates and defaults to two adults" do
      params = ActionController::Parameters.new(check_in: check_in.iso8601, check_out: (check_in + 2).iso8601, adults: "")
      stay = described_class.from_params(params)

      expect(stay.check_in).to eq(check_in)
      expect(stay.adults).to eq(2)
    end
  end
end
