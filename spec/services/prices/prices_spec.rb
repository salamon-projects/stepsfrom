require "rails_helper"

RSpec.describe Prices do
  let(:stay) { Stay.new(check_in: Date.current + 20, check_out: Date.current + 23, adults: 2) }
  let(:listings) { create_list(:listing, 2) }

  around do |example|
    original = Rails.configuration.x.price_providers
    Rails.configuration.x.price_providers = %w[fake]
    example.run
  ensure
    Rails.configuration.x.price_providers = original
  end

  it "caches quotes from inline providers" do
    described_class.refresh(listings, stay)

    quotes = PriceQuote.for_stay(stay)
    expect(quotes.count).to eq(2)
    expect(quotes.first).to have_attributes(source: "fake", currency: "EUR")
    expect(quotes.first.total_cents).to be > 0
    expect(quotes.first.expires_at).to be > Time.current
  end

  it "does not ask again while quotes are fresh" do
    described_class.refresh(listings, stay)
    PriceQuote.update_all(total_cents: 1)

    described_class.refresh(listings, stay)

    expect(PriceQuote.pluck(:total_cents)).to all(eq(1))
  end

  it "re-asks once quotes expire" do
    described_class.refresh(listings, stay)
    PriceQuote.update_all(total_cents: 1, expires_at: 1.minute.ago)

    described_class.refresh(listings, stay)

    expect(PriceQuote.pluck(:total_cents)).to all(be > 1)
  end

  it "queues a job for providers that are not inline" do
    slow = Class.new(Prices::Provider) { def inline? = false }
    allow(described_class).to receive(:providers).and_return([ slow.new ])

    expect { described_class.refresh(listings, stay) }.to have_enqueued_job(RefreshPricesJob)
  end

  it "does nothing without providers" do
    Rails.configuration.x.price_providers = []

    described_class.refresh(listings, stay)

    expect(PriceQuote.count).to eq(0)
  end
end
