require "rails_helper"

RSpec.describe "Public pages" do
  let(:destination) { create(:destination, name: "Makarska Riviera", sea_name: "Adriatic Sea") }
  let!(:hotel) do
    create(:property, :direct, destination:, name: "Hotel Riva", stars: 4, distance_to_water_m: 18,
                                         beach_surface: "pebble", crosses_promenade: true)
  end
  let(:check_in) { Date.current + 30 }
  let(:stay_params) { { check_in: check_in.iso8601, check_out: (check_in + 3).iso8601, adults: 2 } }

  describe "home" do
    it "lists published destinations with verified counts" do
      create(:destination, name: "Hidden Coast", published: false)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Makarska Riviera", "1 verified stay", "1 right on the beach")
      expect(response.body).not_to include("Hidden Coast")
    end

    it "does not count campsites" do
      create(:property, :direct, destination:, kind: "camp_site", name: "Kamp Dolac")

      get root_path

      expect(response.body).to include("1 verified stay", "1 right on the beach")
      expect(Nokogiri::HTML(response.body).at_css("select#destination option[value='#{destination.slug}']")["data-count"]).to eq("1")
    end

    it "gives the destination options what the searchable list shows" do
      get root_path

      document = Nokogiri::HTML(response.body)
      option = document.at_css("select#destination option[value='#{destination.slug}']")
      expect(option.parent["label"]).to eq("Croatia")
      expect(option.to_h).to include("data-sea" => "Adriatic Sea", "data-count" => "1")
      expect(document.at_css("select#destination")["required"]).to be_present
      labels = JSON.parse(document.at_css("form[data-search-form]")["data-search-form"])
      expect(labels).to include("where_to" => "Where are you going?", "stays" => hash_including("one" => "1 verified stay"))
    end

    it "lists Greece first, then the other countries alphabetically" do
      %w[IT GR ES].each { |code| create(:property, :direct, destination: create(:destination, country_code: code)) }

      get root_path

      document = Nokogiri::HTML(response.body)
      expect(document.css("select#destination optgroup").map { |group| group["label"] })
        .to eq(%w[Greece Croatia Italy Spain])
      expect(document.css(".country-tab").map { |tab| tab.text.strip[/\A\D+?(?=\s*\d)/] })
        .to eq(%w[Greece Croatia Italy Spain])
      expect(document.css(".site-footer__nav").first.css("a").map(&:text)).to eq(%w[Greece Croatia Italy Spain])
    end

    it "sends the search form to the destination with the stay" do
      get search_path(destination: destination.slug, **stay_params)

      expect(response).to redirect_to(destination_path(destination, stay_params))
    end

    it "shows a notice instead of an unusable search form without destinations" do
      Destination.update_all(published: false)

      get root_path

      expect(response.body).to include("still measuring our first coastline")
      expect(Nokogiri::HTML(response.body).at_css("form.search-form")).to be_nil
    end

    it "offers a skip link to the main content" do
      get root_path

      document = Nokogiri::HTML(response.body)
      expect(document.at_css("a.skip-link")["href"]).to eq("#main")
      expect(document.at_css("main#main")).to be_present
    end

    it "asks for a destination when none is chosen" do
      get search_path(destination: "")

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "destination" do
    it "shows only published properties with their measurement" do
      create(:property, :direct, :hidden, destination:, name: "Hidden Hotel")
      create(:property, :not_waterfront, destination:, name: "Inland Hotel")

      get destination_path(destination)

      expect(response.body).to include("Hotel Riva", "Verified beachfront", "Pebble beach", "A promenade or path runs in front")
      expect(Nokogiri::HTML(response.body).at_css(".waterfront-summary__distance").text.squish)
        .to eq("Measured 18 m to the Adriatic Sea")
      expect(response.body).not_to include("Hidden Hotel", "Inland Hotel")
      expect(response.body).to include("data-map=")
    end

    it "leaves campsites out of the list, the count and the kind filter" do
      create(:property, :direct, destination:, kind: "camp_site", name: "Kamp Dolac")

      get destination_path(destination)

      document = Nokogiri::HTML(response.body)
      expect(response.body).not_to include("Kamp Dolac")
      expect(document.at_css("meta[name=description]")["content"]).to start_with("1 hotel and apartment in")
      expect(document.css("select#kind option").map { |option| option["value"] }).to include("hostel").and(satisfy { |values| values.exclude?("camp_site") })

      get destination_path(destination, kind: "camp_site")

      expect(Nokogiri::HTML(response.body).css(".property-card__name").map(&:text)).to eq([ "Hotel Riva" ])
    end

    it "links offers through the outbound redirect, marked sponsored" do
      listing = create(:listing, property: hotel)

      get destination_path(destination)

      document = Nokogiri::HTML(response.body)
      link = document.at_css("a.offer__link")
      expect(link["href"]).to eq(outbound_path(listing))
      expect(link["rel"]).to include("sponsored")
    end

    it "orders by price when dates are given and prices are known" do
      cheap = create(:property, :walkable, destination:, name: "Budget Rooms")
      create(:listing, property: hotel)
      create(:listing, property: cheap)
      Rails.configuration.x.price_providers = %w[fake]
      allow_any_instance_of(Prices::Providers::Fake).to receive(:quotes_for) do |_, listings, _|
        listings.map { |l| Prices::Quote.new(listing_id: l.id, total_cents: l.property_id == cheap.id ? 20_000 : 50_000, currency: "EUR") }
      end

      get destination_path(destination, stay_params)

      names = Nokogiri::HTML(response.body).css(".property-card__name").map(&:text)
      expect(names).to eq([ "Budget Rooms", "Hotel Riva" ])
      expect(response.body).to include("€200", "Best price", "noindex")
      expect(response.body).to include(outbound_path(Listing.find_by(property: cheap), stay_params).gsub("&", "&amp;"))
    ensure
      Rails.configuration.x.price_providers = []
    end

    it "reloads once while prices are fetched in the background" do
      create(:listing, property: hotel)
      slow = Class.new(Prices::Provider) { def inline? = false }
      allow(Prices).to receive(:providers).and_return([ slow.new ])

      get destination_path(destination, stay_params)

      refresh = Nokogiri::HTML(response.body).at_css("meta[http-equiv=refresh]")
      expect(refresh["content"]).to start_with("5;url=#{destination_path(destination)}?").and include("priced=1", "check_in=")
      expect(response.body).to include("Getting live prices")

      get destination_path(destination, stay_params.merge(priced: 1))

      expect(Nokogiri::HTML(response.body).at_css("meta[http-equiv=refresh]")).to be_nil
      expect(response.body).to include("have live prices for these dates yet")
    end

    it "folds the filters and summarises the current search" do
      get destination_path(destination, stay_params.merge(surface: "pebble"))

      filters = Nokogiri::HTML(response.body).at_css("details.filters")
      expect(filters["open"]).to be_nil
      expect(filters.at_css(".filters__current").text).to eq(
        "#{check_in.strftime('%-d %b')} – #{(check_in + 3).strftime('%-d %b')} · 2 adults · 1 filter · Lowest price"
      )
    end

    it "counts children in the summary and keeps their ages in the form" do
      get destination_path(destination, stay_params.merge(children: 2, child_ages: [ 4, 9 ]))

      page = Nokogiri::HTML(response.body)
      expect(page.at_css(".filters__current").text).to include("2 adults · 2 children")
      expect(page.at_css("#child_age_1 option[selected]")["value"]).to eq("4")
      expect(page.at_css("#child_age_2 option[selected]")["value"]).to eq("9")
      expect(page.css(".child-ages select[name='child_ages[]']").size).to eq(2)
    end

    it "renders age fields only for the children asked for, plus one template" do
      get destination_path(destination, stay_params)

      page = Nokogiri::HTML(response.body)
      expect(page.css(".child-ages .child-ages__field")).to be_empty
      expect(page.css("select[name='child_ages[]']").size).to eq(1)
      template = page.at_css("template.child-ages__template")
      expect(template.css("select[name='child_ages[]'] option").size).to eq(Stay::CHILD_AGES.count + 1)
      expect(page.at_css(".child-ages")["data-label"]).to eq("Child %{number}")
    end

    it "asks for missing ages with a field per child, without JavaScript" do
      get destination_path(destination, stay_params.merge(children: 2))

      page = Nokogiri::HTML(response.body)
      expect(page.at_css(".form-error").text).to include("Child ages are needed for every child")
      expect(page.css(".child-ages select").map { |select| select["id"] }).to eq(%w[child_age_1 child_age_2])
    end

    it "keeps the filters open when the dates need correcting" do
      get destination_path(destination, check_in: check_in.iso8601, check_out: (check_in - 1).iso8601)

      expect(Nokogiri::HTML(response.body).at_css("details.filters")["open"]).not_to be_nil
    end

    it "shows a validation message for impossible dates" do
      get destination_path(destination, check_in: check_in.iso8601, check_out: (check_in - 1).iso8601)

      expect(response.body).to include("Check out must be after check-in")
    end

    it "returns 404 for unpublished destinations" do
      destination.update!(published: false)

      get destination_path(destination)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "property" do
    it "shows the checks and the map" do
      get property_path(hotel)

      document = Nokogiri::HTML(response.body)
      expect(document.at_css(".map")["role"]).to eq("region")
      sections = document.css(".property-layout > *").map { |node| node["class"] }
      expect(sections).to eq(%w[property-layout__summary property-layout__booking property-layout__details])

      expect(response.body).to include("Hotel Riva", "What we checked", "No road or railway between", "data-map=")
      expect(Nokogiri::HTML(response.body).at_css("link[rel=canonical]")["href"]).to eq(property_url(hotel))
    end

    it "shows the official website instead of a price form when no booking site lists it" do
      hotel.update!(website: "https://hotel-riva.example")

      get property_path(hotel)

      panel = Nokogiri::HTML(response.body).at_css(".booking-panel")
      expect(panel.text).to include("Not bookable through our partners yet", "More verified stays in Makarska Riviera")
      expect(panel.at_css("a[href='https://hotel-riva.example']")["rel"]).to eq("nofollow noopener")
      expect(panel.at_css("form")).to be_nil
    end

    it "leaves out an official website that leads nowhere" do
      hotel.update!(website: "https://hotel-riva.example")
      hotel.update_columns(website_broken_at: Time.current, website_status: "empty page")

      get property_path(hotel)

      expect(response.body).not_to include("hotel-riva.example")
      expect(response.body).to include("More verified stays in Makarska Riviera")
    end

    it "warns about a road between the property and the water" do
      hotel.waterfront.update!(crosses_road: true, category: "near")

      get property_path(hotel)

      expect(response.body).to include("A road or railway runs between the property and the water")
    end

    it "redirects a campsite's page permanently to its destination page" do
      camp = create(:property, :direct, destination:, kind: "camp_site", name: "Kamp Dolac")

      get property_path(camp, check_in: check_in.iso8601)

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(destination_path(destination))
    end

    it "returns 404 for a campsite whose destination is not published" do
      camp = create(:property, :direct, destination: create(:destination, published: false), kind: "camp_site")

      get property_path(camp)

      expect(response).to have_http_status(:not_found)
    end

    it "still shows a hostel" do
      hostel = create(:property, :direct, destination:, kind: "hostel", name: "Hostel Riva")

      get property_path(hostel)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Hostel Riva")
    end

    it "returns 404 for hidden properties" do
      hotel.update!(hidden_at: Time.current)

      get property_path(hotel)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "search engines and sharing" do
    def json_ld(type)
      response.body.scan(%r{<script type="application/ld\+json">(.*?)</script>}m)
              .map { |(data)| JSON.parse(data) }.find { |data| data["@type"] == type }
    end

    it "adds search console verification tags only when configured" do
      get root_path
      expect(response.body).not_to include("google-site-verification", "msvalidate.01")

      stub_const("ENV", ENV.to_h.merge("GOOGLE_SITE_VERIFICATION" => " g00gle-token ", "BING_SITE_VERIFICATION" => "B1NG"))
      get how_we_verify_path

      head = Nokogiri::HTML(response.body).at_css("head")
      expect(head.at_css("meta[name='google-site-verification']")["content"]).to eq("g00gle-token")
      expect(head.at_css("meta[name='msvalidate.01']")["content"]).to eq("B1NG")
    end

    it "describes the site, with sharing tags" do
      get root_path

      expect(json_ld("WebSite")).to include("name" => "StepsFrom", "url" => "http://www.example.com/")
      expect(response.body).to include('content="http://www.example.com/og-image.jpg" property="og:image"',
                                       'content="summary_large_image" name="twitter:card"')
    end

    it "lists a destination's stays and its place in the site" do
      get destination_path(destination) + "/"

      expect(response.body).to include('<link href="http://www.example.com/destinations/makarska-riviera" rel="canonical">')
      expect(json_ld("ItemList")["itemListElement"].first).to include("position" => 1, "name" => "Hotel Riva",
                                                                       "url" => property_url(hotel))
      expect(json_ld("BreadcrumbList")["itemListElement"].pluck("name")).to eq([ "Destinations", destination.country_name, "Makarska Riviera" ])
    end

    it "describes a property as a hotel at its measured position" do
      hotel.update!(name: "Hotel </script> Riva", address: "Obala 1", website: "https://riva.example/")

      get property_path(hotel)

      expect(response.body).not_to include("Hotel </script> Riva\"")
      expect(json_ld("Hotel")).to include(
        "name" => "Hotel </script> Riva", "url" => property_url(hotel), "sameAs" => "https://riva.example/",
        "starRating" => { "@type" => "Rating", "ratingValue" => 4 },
        "address" => { "@type" => "PostalAddress", "streetAddress" => "Obala 1",
                       "addressLocality" => "Makarska Riviera", "addressCountry" => destination.country_code })
      expect(json_ld("Hotel")["geo"]).to include("latitude" => hotel.latitude.round(6))
      expect(json_ld("BreadcrumbList")["itemListElement"].size).to eq(4)
    end
  end

  describe "country" do
    it "gathers a country's coastlines and the stays closest to the water" do
      other = create(:destination, name: "Hvar", country_code: destination.country_code)
      create(:property, :direct, destination: other, name: "Hotel Amfora", distance_to_water_m: 9)
      create(:property, :near, destination: other, name: "Villa Up The Hill")
      create(:destination, name: "Hidden Coast", country_code: destination.country_code, published: false)
      country = Country.new(destination.country_code)

      get country_path(country)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Beachfront stays in #{country.name}", "Makarska Riviera", "Hvar")
      expect(response.body).not_to include("Hidden Coast", "Villa Up The Hill")
      expect(response.body.index("Hotel Amfora")).to be < response.body.index("Hotel Riva")
      expect(response.body).to include(%(href="#{country_path(country)}"))
    end

    it "is linked from the home page, the destination page and the sitemap" do
      country = Country.new(destination.country_code)

      [ root_path, destination_path(destination), property_path(hotel) ].each do |path|
        get path
        expect(response.body).to include(%(href="#{country_path(country)}"))
      end
      get sitemap_path
      expect(response.body).to include(country_url(country))
    end

    it "does not count or show campsites" do
      create(:property, :direct, destination:, kind: "camp_site", name: "Kamp Dolac", distance_to_water_m: 1)

      get country_path(Country.new(destination.country_code))

      expect(response.body).not_to include("Kamp Dolac")
      expect(Nokogiri::HTML(response.body).at_css("meta[name=description]")["content"]).to start_with("1 verified waterfront stay")
    end

    it "is not found for a country without published destinations" do
      get country_path("narnia")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "static pages" do
    it "explains the method with the configured thresholds" do
      get how_we_verify_path

      expect(response.body).to include("How results are ordered", "at most #{Waterfront.config.fetch(:direct_max_m)} m away")
      expect(response.body.squish).to include("We do not list campsites, however close they are to the water.")
    end

    it "renders the disclosure and privacy pages" do
      get affiliate_disclosure_path
      expect(response).to have_http_status(:ok)

      get privacy_path
      expect(response.body).to include("IP address")
    end

    it "lists published pages in the sitemap" do
      create(:property, :direct, :hidden, destination:, name: "Hidden Hotel")
      camp = create(:property, :direct, destination:, kind: "camp_site", name: "Kamp Dolac")

      get sitemap_path

      expect(response.media_type).to eq("application/xml")
      expect(response.body).to include(destination_url(destination), property_url(hotel), guide_url("makarska-hotels-on-the-beach"))
      expect(response.body.scan("<url>").size).to eq(6)
      expect(response.body).not_to include(property_url(camp))
    end

    describe "sitemap" do
      def sitemap
        get sitemap_path
        Nokogiri::XML(response.body).remove_namespaces!.css("url").to_h do |url|
          [ url.at_css("loc").text, url.at_css("lastmod")&.text ]
        end
      end

      it "lists home and guides first, then the other hubs, then stays best waterfront first" do
        walkable = create(:property, :walkable, destination:, name: "Villa Uphill")
        near = create(:property, :near, destination:, name: "Hotel Across The Road")
        closest = create(:property, :direct, destination:, name: "Hotel Shore", distance_to_water_m: 5)

        expect(sitemap.keys).to eq([
          root_url, guide_url("makarska-hotels-on-the-beach"), destination_url(destination), country_url(Country.new(destination.country_code)), how_we_verify_url,
          property_url(closest), property_url(hotel), property_url(near), property_url(walkable)
        ])
      end

      it "dates each page by its last real change, not today" do
        hotel.update_columns(updated_at: Time.utc(2026, 9, 1, 8))
        hotel.waterfront.update_columns(updated_at: Time.utc(2026, 10, 2, 9))
        destination.update_columns(updated_at: Time.utc(2026, 8, 1))

        lastmods = sitemap
        expect(lastmods[property_url(hotel)]).to eq("2026-10-02T09:00:00Z")
        expect(lastmods[destination_url(destination)]).to eq("2026-10-02T09:00:00Z")
        expect(lastmods[root_url]).to eq("2026-10-02T09:00:00Z")
        expect(lastmods[country_url(Country.new(destination.country_code))]).to eq("2026-10-02T09:00:00Z")
        expect(lastmods[how_we_verify_url]).to be_nil
      end

      it "leaves out short-walk stays when SITEMAP_EXCLUDE_WALKABLE is set" do
        walkable = create(:property, :walkable, destination:)
        expect(sitemap).to include(property_url(walkable))

        stub_const("ENV", ENV.to_h.merge("SITEMAP_EXCLUDE_WALKABLE" => "1"))
        urls = sitemap.keys
        expect(urls).to include(property_url(hotel))
        expect(urls).not_to include(property_url(walkable))
      end
    end

    it "points robots to the sitemap and away from redirects" do
      get "/robots.txt"

      expect(response.body).to include("Disallow: /go/", "Sitemap: #{sitemap_url}")
    end
  end
end
