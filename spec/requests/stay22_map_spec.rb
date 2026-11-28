require "rails_helper"

RSpec.describe "Stay22 map with live prices" do
  let(:destination) { create(:destination, name: "Makarska Riviera", slug: "makarska-riviera") }
  let!(:hotel) { create(:property, :direct, destination:, name: "Hotel Riva") }
  let(:check_in) { Date.current + 30 }
  let(:stay_params) { { check_in: check_in.iso8601, check_out: (check_in + 3).iso8601, adults: 2, children: 1, child_ages: [ 6 ] } }

  def document
    Nokogiri::HTML(response.body)
  end

  def map_query
    url = URI.parse(document.at_css("[data-stay22-map]")["data-stay22-map"])
    expect(url.to_s).to start_with("https://www.stay22.com/embed/gm?")
    Rack::Utils.parse_query(url.query)
  end

  context "without STAY22_AID" do
    before { stub_const("ENV", ENV.to_h.except("STAY22_AID")) }

    it "renders nothing on property and destination pages" do
      [ property_path(hotel), destination_path(destination) ].each do |path|
        get path

        expect(document.at_css(".stay22-map")).to be_nil, path
        expect(response.body).not_to include("stay22_map", "stay22.com")
      end
    end
  end

  context "with STAY22_AID" do
    before { stub_const("ENV", ENV.to_h.merge("STAY22_AID" => "stepsfrom")) }

    it "offers the map on a property page, zoomed in on the property" do
      get property_path(hotel)

      section = document.at_css("section.stay22-map")
      expect(section["hidden"]).not_to be_nil
      expect(section.at_css("button[type=button]").text).to eq("Show map with live prices")
      expect(section["data-stay22-map-title"]).to include("Hotel Riva")
      expect(map_query).to eq("aid" => "stepsfrom", "lat" => hotel.lonlat.y.round(6).to_s, "lng" => hotel.lonlat.x.round(6).to_s,
                              "zoom" => "15", "campaign" => "makarska_riviera")
    end

    it "offers the map on a destination page, centred on the destination" do
      get destination_path(destination)

      expect(map_query).to include("aid" => "stepsfrom", "lat" => destination.center.y.round(6).to_s,
                                   "lng" => destination.center.x.round(6).to_s, "zoom" => "12", "campaign" => "makarska_riviera")
    end

    it "passes a valid stay on, with only documented parameters" do
      get property_path(hotel, stay_params)

      expect(map_query).to include("checkin" => check_in.iso8601, "checkout" => (check_in + 3).iso8601, "adults" => "2", "children" => "1")
      expect(map_query.keys).to all(be_in(%w[aid lat lng checkin checkout adults children zoom campaign]))
      expect(response.body).not_to include("priceper")
    end

    it "leaves an invalid stay out" do
      get destination_path(destination, check_in: check_in.iso8601, check_out: check_in.iso8601)

      expect(map_query.keys).not_to include("checkin", "checkout", "adults")
    end

    it "loads nothing from Stay22 before the click" do
      [ property_path(hotel, stay_params), destination_path(destination) ].each do |path|
        get path

        expect(document.css("iframe")).to be_empty, path
        expect(document.css("script[src]").map { |script| script["src"] }).to all(start_with("/")), path
        expect(document.css("script[src]").map { |script| script["src"] }).to include(a_string_including("stay22_map"))
        expect(document.css("link[href*='stay22'], img[src*='stay22']")).to be_empty, path
        expect(response.body.scan("stay22.com").size).to eq(1), path
      end
    end
  end

  it "allows frames only from Stay22 and keeps the other directives strict" do
    get destination_path(destination)

    directives = response.headers["Content-Security-Policy"].split(";").map(&:strip).to_h { |d| d.split(" ", 2) }
    expect(directives).to include("frame-src" => "https://www.stay22.com", "default-src" => "'self'",
                                  "script-src" => "'self'", "style-src" => "'self'", "connect-src" => "'self'",
                                  "object-src" => "'none'", "frame-ancestors" => "'none'")
  end
end
