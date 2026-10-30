require "rails_helper"

RSpec.describe ImportRun do
  let(:destination) { create(:destination) }

  it "is active while queued, running or retrying, until it goes stale" do
    run = destination.import_runs.create!

    expect(run).to be_active
    expect(described_class.active).to include(run)

    travel 61.minutes do
      expect(run).not_to be_active
      expect(run).to be_interrupted
      expect(described_class.active).not_to include(run)
    end
  end

  it "picks the latest run per destination" do
    other = create(:destination)
    old_run = destination.import_runs.create!(created_at: 2.days.ago)
    new_run = destination.import_runs.create!
    other_run = other.import_runs.create!

    latest = described_class.latest_by_destination
    expect(latest[destination.id]).to eq(new_run)
    expect(latest[other.id]).to eq(other_run)
    expect(latest.values).not_to include(old_run)
  end
end
