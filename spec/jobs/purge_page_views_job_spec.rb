require "rails_helper"

RSpec.describe PurgePageViewsJob do
  it "deletes page views past the retention period and keeps the rest" do
    create_view = ->(time) { PageView.create!(occurred_at: time, path: "/", visitor_hash: "abc") }
    create_view.(200.days.ago)
    create_view.(181.days.ago)
    recent = create_view.(2.days.ago)

    described_class.perform_now

    expect(PageView.all).to contain_exactly(recent)
  end

  it "is scheduled daily in production" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"))

    expect(recurring.dig("production", "purge_old_page_views", "class")).to eq("PurgePageViewsJob")
  end
end
