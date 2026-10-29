require "rails_helper"

RSpec.describe Offer do
  let(:property) { create(:property) }
  let(:stay) { Stay.new(check_in: Date.current + 20, check_out: Date.current + 23, adults: 2) }
  let!(:booking) { create(:listing, property:) }
  let!(:agoda) { create(:listing, :agoda, property:) }
  let!(:expedia) { create(:listing, :expedia, property:) }

  def offers(for_stay = stay)
    described_class.for_properties([ property.reload ], for_stay).fetch(property.id)
  end

  it "orders by provider without prices" do
    expect(offers(nil).map(&:listing)).to eq([ booking, expedia, agoda ])
    expect(offers(nil).map(&:best)).to all(be(false))
  end

  it "puts the cheapest fresh price first and marks it best" do
    create(:price_quote, listing: booking, total_cents: 40_000, **stay.to_params)
    create(:price_quote, listing: agoda, total_cents: 35_000, **stay.to_params)
    create(:price_quote, listing: expedia, total_cents: 10_000, expires_at: 1.minute.ago, **stay.to_params)

    result = offers
    expect(result.map(&:listing)).to eq([ agoda, booking, expedia ])
    expect(result.map(&:best)).to eq([ true, false, false ])
    expect(result.last.quote).to be_nil
  end
end
