require "rails_helper"

RSpec.describe "Admin analytics" do
  let(:destination) { create(:destination, name: "Hvar") }
  let(:guide_path_string) { "/guides/hvar-beachfront-hotels" }
  let(:hotel) { create(:property, :direct, destination:, name: "Hotel Amfora") }
  let(:listing) { create(:listing, property: hotel) }

  def document
    Nokogiri::HTML(response.body)
  end

  def section(title)
    document.css("section.admin-card").find { |card| card.at_css("h2").text == title }
  end

  def rows(title)
    section(title).css("tbody tr").map { |row| row.css("td").map { |cell| cell.text.squish } }
  end

  def view(path, at: 1.hour.ago, visitor: "v1", **attributes)
    PageView.create!(occurred_at: at, path:, visitor_hash: visitor, device: "desktop", **attributes)
  end

  before do
    view "/", visitor: "v1", referrer_host: "www.google.com", utm_source: "newsletter", utm_campaign: "spring"
    view "/", visitor: "v2", country: "DE", device: "mobile"
    view guide_path_string, visitor: "v1"
    view guide_path_string, visitor: "v2"
    view guide_path_string, visitor: "v3", at: 3.days.ago
    view "/privacy", at: 20.days.ago
    view "/privacy", at: 200.days.ago

    OutboundClick.create!(listing:, property: hotel, provider: "booking", source_path: guide_path_string, created_at: 2.hours.ago)
    OutboundClick.create!(provider: "getyourguide", source_path: guide_path_string, created_at: 2.hours.ago)
    OutboundClick.create!(provider: "viator", source_path: "/destinations/hvar", created_at: 2.hours.ago)
    OutboundClick.create!(provider: "viator", source_path: "/destinations/hvar", created_at: 5.days.ago)
  end

  it "requires signing in" do
    get admin_analytics_path

    expect(response).to redirect_to(admin_login_path)
  end

  it "is linked from the admin menu" do
    sign_in_admin
    get admin_properties_path

    expect(document.at_css("nav.site-nav a[href='#{admin_analytics_path}']").text).to eq("Analytics")
  end

  it "shows the last 24 hours" do
    sign_in_admin
    get admin_analytics_path(days: 1)

    expect(response).to have_http_status(:ok)
    expect(document.at_css(".admin-tabs a[aria-current=page]").text).to eq("Last 24 hours")
    summary = document.css(".analytics-summary div").to_h { |item| [ item.at_css("dt").text, item.at_css("dd").text ] }
    expect(summary).to eq("Page views" => "4", "Visitors (unique per day)" => "2", "Click-outs" => "3",
                          "Click-outs per page view" => "75.0%")
    expect(rows("Top pages").map { |row| row.first(3) }).to eq([ [ "/", "2", "2" ], [ guide_path_string, "2", "2" ] ])
    expect(rows("Top referrers").map(&:first)).to eq([ "www.google.com" ])
    expect(rows("Campaigns (UTM)").map { |row| row.first(3) }).to eq([ %w[newsletter – spring] ])
    expect(rows("Countries").map(&:first)).to eq([ "DE" ])
    expect(rows("Click-outs by site")).to contain_exactly(%w[Booking.com 1], %w[GetYourGuide 1], %w[Viator 1])
    expect(rows("Most clicked properties")).to eq([ [ "Hotel Amfora", "Booking.com", "1" ] ])
    expect(rows("Things to do (activity sites)")).to contain_exactly(
      [ "GetYourGuide", "Hvar", guide_path_string, "1" ], [ "Viator", "Hvar", "/destinations/hvar", "1" ]
    )
    expect(rows("Guide click-through")).to eq([ [ "Hvar beachfront hotels, measured to the water #{guide_path_string}", "2", "2", "100.0%" ] ])
    expect(response.body).not_to include("style=")
  end

  it "shows the last 7 days by default, day by day" do
    sign_in_admin
    get admin_analytics_path

    expect(document.at_css(".admin-tabs a[aria-current=page]").text).to eq("Last 7 days")
    expect(rows("By day").size).to eq(8)
    expect(rows("By day").sum { |row| row[1].to_i }).to eq(5)
    expect(rows("By day").sum { |row| row[3].to_i }).to eq(4)
    expect(rows("Things to do (activity sites)")).to include([ "Viator", "Hvar", "/destinations/hvar", "2" ])
    expect(rows("Guide click-through").first.drop(1)).to eq([ "3", "2", "66.7%" ])
  end

  it "shows the last 30 days and nothing older" do
    sign_in_admin
    get admin_analytics_path(days: 30)

    expect(response).to have_http_status(:ok)
    expect(document.at_css(".admin-tabs a[aria-current=page]").text).to eq("Last 30 days")
    expect(rows("Top pages").find { |row| row.first == "/privacy" }[1]).to eq("1")
    expect(rows("By day").size).to eq(31)
  end

  it "renders with no data" do
    PageView.delete_all
    OutboundClick.delete_all
    sign_in_admin
    get admin_analytics_path(days: 7)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No page views in this period.", "No click-outs in this period.")
  end
end
