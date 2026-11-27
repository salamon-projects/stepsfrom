require "rails_helper"

RSpec.describe "Things to do (activity sites)" do
  let(:destination) { create(:destination, name: "Hvar", sea_name: "Adriatic Sea") }
  let(:guide_slug) { "hvar-beachfront-hotels" }

  before do
    create(:property, :direct, destination:, name: "Hotel Amfora", distance_to_water_m: 9)
    with_env({})
  end

  def with_env(values)
    blank = { "GETYOURGUIDE_PARTNER_ID" => "", "VIATOR_PID" => "", "VIATOR_MCID" => "" }
    stub_const("ENV", ENV.to_h.merge(blank, values))
  end

  def block
    Nokogiri::HTML(response.body).at_css(".activities")
  end

  def links
    block.css("a").to_h { |link| [ link.text.squish, link ] }
  end

  describe "pages" do
    it "renders nothing on destination and guide pages when no ids are set" do
      [ destination_path(destination), guide_path(guide_slug) ].each do |path|
        get path

        expect(response).to have_http_status(:ok)
        expect(block).to be_nil
        expect(response.body).not_to include("Things to do", "getyourguide", "viator")
      end
    end

    it "shows only GetYourGuide when only its partner id is set" do
      with_env("GETYOURGUIDE_PARTNER_ID" => "GYG1")

      get destination_path(destination)

      expect(block.at_css("h2").text).to eq("Things to do around Hvar")
      expect(links.keys).to eq([ "Browse on GetYourGuide" ])
      expect(links["Browse on GetYourGuide"]["href"]).to eq(activities_outbound_path("getyourguide", destination))
    end

    it "shows only Viator when both its ids are set" do
      with_env("VIATOR_PID" => "P00012345", "VIATOR_MCID" => "42383")

      get destination_path(destination)

      expect(links.keys).to eq([ "Browse on Viator" ])
    end

    it "shows nothing when Viator has only one of its ids" do
      with_env("VIATOR_PID" => "P00012345")
      get destination_path(destination)
      expect(block).to be_nil

      with_env("VIATOR_MCID" => "42383")
      get guide_path(guide_slug)
      expect(block).to be_nil
    end

    it "shows both on destination and guide pages, as sponsored links in a new tab" do
      with_env("GETYOURGUIDE_PARTNER_ID" => "GYG1", "VIATOR_PID" => "P00012345", "VIATOR_MCID" => "42383")

      [ destination_path(destination), guide_path(guide_slug) ].each do |path|
        get path

        expect(links.keys).to eq([ "Browse on GetYourGuide", "Browse on Viator" ])
        links.each_value do |link|
          expect(link["rel"]).to eq("sponsored nofollow noopener")
          expect(link["target"]).to eq("_blank")
        end
        expect(block.text).to include("We haven't checked them", "Sponsored links")
      end
    end

    it "mentions the activity sites on the affiliate disclosure page only when configured" do
      get affiliate_disclosure_path
      expect(response.body).not_to include("GetYourGuide")

      with_env("GETYOURGUIDE_PARTNER_ID" => "GYG1")
      get affiliate_disclosure_path
      expect(response.body).to include("activity sites (GetYourGuide)")
    end
  end

  describe "outbound redirect" do
    it "logs the click and redirects to GetYourGuide's search with our partner id" do
      with_env("GETYOURGUIDE_PARTNER_ID" => "GYG1")

      expect {
        get activities_outbound_path("getyourguide", destination),
            headers: { "Referer" => "http://www.example.com/guides/#{guide_slug}?adults=2" }
      }.to change(OutboundClick, :count).by(1)

      expect(response).to have_http_status(:found)
      expect(response.location).to eq("https://www.getyourguide.com/s/?q=Hvar&partner_id=GYG1")
      expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
      expect(OutboundClick.last).to have_attributes(provider: "getyourguide", listing: nil, property: nil,
                                                    source_path: "/guides/#{guide_slug}")
    end

    it "redirects to Viator's search with pid, mcid, medium and campaign" do
      with_env("VIATOR_PID" => "P00012345", "VIATOR_MCID" => "42383")

      get activities_outbound_path("viator", destination)

      expect(response.location).to eq("https://www.viator.com/searchResults/all?text=Hvar&pid=P00012345&mcid=42383&medium=link&campaign=hvar")
      expect(OutboundClick.last).to have_attributes(provider: "viator", listing: nil, property: nil)
    end

    it "is not found when the provider's ids are unset" do
      with_env("VIATOR_PID" => "P00012345")

      expect {
        get activities_outbound_path("getyourguide", destination)
        expect(response).to have_http_status(:not_found)
        get activities_outbound_path("viator", destination)
        expect(response).to have_http_status(:not_found)
      }.not_to change(OutboundClick, :count)
    end

    it "is not found for an unknown provider or an unpublished destination" do
      with_env("GETYOURGUIDE_PARTNER_ID" => "GYG1")
      hidden = create(:destination, name: "Secret Cove", published: false)

      expect {
        get activities_outbound_path("klook", destination)
        expect(response).to have_http_status(:not_found)
        get activities_outbound_path("getyourguide", hidden)
        expect(response).to have_http_status(:not_found)
      }.not_to change(OutboundClick, :count)
    end
  end
end
