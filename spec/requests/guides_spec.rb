require "rails_helper"

RSpec.describe "Guides" do
  let(:destination) { create(:destination, name: "Hvar", sea_name: "Adriatic Sea") }
  let(:guide_slug) { "hvar-beachfront-hotels" }
  let!(:amfora) do
    create(:property, :direct, destination:, name: "Hotel Amfora", stars: 4, distance_to_water_m: 9,
                               beach_surface: "pebble", distance_to_beach_m: 4)
  end
  let!(:palace) { create(:property, :direct, destination:, name: "Palace Hotel", distance_to_water_m: 35) }
  let!(:villa) { create(:property, :near, destination:, name: "Villa Across", distance_to_water_m: 6, crosses_road: true) }
  let!(:rooms) { create(:property, :walkable, destination:, name: "Rooms Uphill", distance_to_water_m: 210) }

  def document
    Nokogiri::HTML(response.body)
  end

  def json_ld(type)
    document.css("script[type='application/ld+json']").map { |script| JSON.parse(script.text) }.find { |data| data["@type"] == type }
  end

  describe "page" do
    it "has its own title, description, H1 and canonical URL" do
      get guide_path(guide_slug)

      expect(response).to have_http_status(:ok)
      expect(document.at_css("title").text).to eq("Hvar beachfront hotels, measured to the water · StepsFrom")
      expect(document.at_css("meta[name=description]")["content"])
        .to start_with("The best beachfront hotels in Hvar, ranked by measured distance to the Adriatic Sea: 2 verified beachfront")
        .and include("The closest is 6 m from the water.")
      expect(document.css("h1").map(&:text)).to eq([ "Best beachfront hotels in Hvar" ])
      expect(document.at_css("link[rel=canonical]")["href"]).to eq(guide_url(guide_slug))
      expect(document.at_css("meta[name=robots]")).to be_nil
    end

    it "explains the measurement with the configured thresholds and the data" do
      get guide_path(guide_slug)

      intro = document.at_css(".guide-intro").text.squish
      expect(intro).to include("shortest straight line to the shoreline of the Adriatic Sea",
                               "at most #{Waterfront.config.fetch(:direct_max_m)} m away",
                               "We have measured 4 places to stay on Hvar that pass, 2 of them verified beachfront",
                               "not a walking route")
      expect(document.at_css(".guide-intro a")["href"]).to eq(how_we_verify_path)
    end

    it "ranks verified beachfront first, then by distance, with badge, distance and a factual line" do
      create(:property, :not_waterfront, destination:, name: "Inland Hotel")
      create(:property, :direct, :hidden, destination:, name: "Hidden Hotel")

      get guide_path(guide_slug)

      cards = document.css(".guide-ranking__list > li")
      expect(cards.map { |card| card.at_css(".property-card__name").text }).to eq([ "Hotel Amfora", "Palace Hotel", "Villa Across", "Rooms Uphill" ])
      expect(cards.first.at_css(".property-card__name a")["href"]).to eq(property_path(amfora))
      expect(cards.first.at_css(".badge").text).to eq("Verified beachfront")
      expect(cards.first.at_css(".waterfront-summary__distance").text.squish).to eq("Measured 9 m to the Adriatic Sea")
      expect(cards.first.at_css(".property-card__note").text).to eq(
        "Hotel Amfora is 9 m from the Adriatic Sea in a straight line, with no road or railway in between. " \
        "Nearest mapped beach: 4 m away, pebble beach."
      )
      expect(cards[2].at_css(".property-card__note").text).to include("but a road or railway runs in between")
      expect(response.body).not_to include("Inland Hotel", "Hidden Hotel")
      expect(document.at_css(".guide-ranking__title").text).to eq("The 4 closest to the water")
    end

    it "leaves campsites and hostels out of the list and the figures, and says so" do
      create(:property, :direct, destination:, kind: "camp_site", name: "Kamp Dolac", distance_to_water_m: 1)
      create(:property, :direct, destination:, kind: "hostel", name: "Hostel Riva", distance_to_water_m: 2)

      get guide_path(guide_slug)

      expect(document.css(".guide-ranking__list .property-card__name").map(&:text))
        .to eq([ "Hotel Amfora", "Palace Hotel", "Villa Across", "Rooms Uphill" ])
      expect(document.at_css(".guide-intro").text.squish)
        .to include("Campsites and hostels are not included. We have measured 4 places to stay on Hvar that pass, 2 of them verified beachfront")
      expect(document.at_css("meta[name=description]")["content"]).to include("2 verified beachfront", "The closest is 6 m from the water.")
      expect(response.body).not_to include("Kamp Dolac", "Hostel Riva")
    end

    it "shows at most the guide's limit" do
      stub_const("Guide::DEFAULT_LIMIT", 2)

      get guide_path(guide_slug)

      expect(document.css(".guide-ranking__list .property-card__name").map(&:text)).to eq([ "Hotel Amfora", "Palace Hotel" ])
      expect(document.at_css(".guide-ranking__title").text).to eq("The 2 closest to the water")
    end

    it "links booking sites through the outbound redirect, marked sponsored" do
      listing = create(:listing, property: amfora)
      create(:listing, :expedia, property: amfora, active: false)

      get guide_path(guide_slug)

      links = document.css(".guide-ranking__list a.offer__link")
      expect(links.map { |link| link["href"] }).to eq([ outbound_path(listing) ])
      expect(links.first["rel"]).to eq("sponsored nofollow noopener")
      expect(links.first["target"]).to eq("_blank")
      expect(document.at_css("a.offers__dates")["href"]).to eq("#check_in")
      expect(response.body).to include("We may earn a commission")
    end

    it "answers questions from the data" do
      get guide_path(guide_slug)

      faq = document.at_css(".guide-faq")
      expect(faq.css("h3").size).to be_between(3, 5)
      expect(faq.text.squish).to include("Verified beachfront: 2 of the 4 places to stay in this guide",
                                         "Villa Across: 6 m from the water, measured in a straight line")
    end

    it "shows breadcrumbs from home to the destination" do
      get guide_path(guide_slug)

      links = document.css("nav.breadcrumbs a").map { |link| link["href"] }
      expect(links).to eq([ root_path(anchor: "destinations"), country_path(Country.new("HR")), destination_path(destination) ])
    end
  end

  describe "dates and guests" do
    let(:check_in) { Date.current + 30 }
    let(:stay_params) { { check_in: check_in.iso8601, check_out: (check_in + 3).iso8601, adults: 2 } }
    let(:family_params) { stay_params.merge(children: 2, child_ages: [ 4, 9 ]) }

    it "has the stay form, a plain GET back to the guide" do
      get guide_path(guide_slug)

      form = document.at_css(".guide-stay form")
      expect(form["action"]).to eq(guide_path(guide_slug))
      expect(form["method"]).to eq("get")
      expect(form.css("input, select").map { |field| field["name"] }.compact)
        .to include("check_in", "check_out", "adults", "children")
      expect(form.at_css("template.child-ages__template select[name='child_ages[]']")).to be_present
      expect(form.at_css("input[type=submit]")["value"]).to eq("See prices")
      expect(document.css("script[src]").map { |script| script["src"] }).to include(a_string_including("stay_fields"))
    end

    it "keeps the stay, guests and children's ages in the booking links, ranked by distance as before" do
      listing = create(:listing, property: amfora)
      create(:listing, property: rooms)

      get guide_path(guide_slug, family_params)

      expect(document.css(".guide-ranking__list .property-card__name").map(&:text))
        .to eq([ "Hotel Amfora", "Palace Hotel", "Villa Across", "Rooms Uphill" ])
      link = document.at_css(".guide-ranking__list a.offer__link")
      expect(link["href"]).to eq(outbound_path(listing, family_params))
      expect(link.text.squish).to include("Check price")
      expect(document.at_css(".guide-ranking__list .property-card__name a")["href"]).to eq(property_path(amfora, family_params))
      expect(document.at_css("a.offers__dates")).to be_nil
      expect(document.at_css(".guide-stay__current").text).to eq(
        "#{check_in.strftime('%-d %b')} – #{(check_in + 3).strftime('%-d %b')} · 2 adults · 2 children"
      )
      expect(document.css(".guide-stay .child-ages select[name='child_ages[]']").map { |select| select.at_css("option[selected]")["value"] })
        .to eq(%w[4 9])
      expect(response.body).not_to include("€")
    end

    it "sends the stay on to Stay22 the way destination pages do" do
      stub_const("ENV", ENV.to_h.merge("STAY22_AID" => "stepsfrom"))
      create(:listing, property: amfora, generator: "stay22", url: Affiliate::Stay22.listing_url(amfora, "booking"))

      get guide_path(guide_slug, family_params)
      get document.at_css(".guide-ranking__list a.offer__link")["href"]

      query = Rack::Utils.parse_query(URI.parse(response.location).query)
      expect(query).to include("aid" => "stepsfrom", "campaign" => destination.slug.tr("-", "_"),
                               "checkin" => check_in.iso8601, "checkout" => (check_in + 3).iso8601,
                               "adults" => "2", "children" => "2", "childrenAges" => "4,9")
    end

    it "shows prices for the stay when a provider has them, without re-sorting" do
      create(:listing, property: amfora)
      create(:listing, property: rooms)
      Rails.configuration.x.price_providers = %w[fake]
      allow_any_instance_of(Prices::Providers::Fake).to receive(:quotes_for) do |_, listings, _|
        listings.map { |l| Prices::Quote.new(listing_id: l.id, total_cents: l.property_id == rooms.id ? 20_000 : 50_000, currency: "EUR") }
      end

      get guide_path(guide_slug, stay_params)

      expect(document.css(".guide-ranking__list .property-card__name").map(&:text).first).to eq("Hotel Amfora")
      expect(response.body).to include("€500", "€200", "Best price")
    ensure
      Rails.configuration.x.price_providers = []
    end

    it "ignores an invalid stay and says what is wrong" do
      listing = create(:listing, property: amfora)

      get guide_path(guide_slug, check_in: (check_in + 3).iso8601, check_out: check_in.iso8601, adults: 2)

      expect(response).to have_http_status(:ok)
      expect(document.at_css(".guide-ranking__list a.offer__link")["href"]).to eq(outbound_path(listing))
      expect(document.at_css(".guide-stay .form-error")).to be_present
      expect(document.at_css(".guide-stay__current")).to be_nil
    end

    it "is not indexed with a stay, and keeps the JSON-LD" do
      get guide_path(guide_slug, stay_params)

      expect(document.at_css("meta[name=robots]")["content"]).to eq("noindex")
      expect(document.at_css("link[rel=canonical]")).to be_nil
      expect(json_ld("ItemList")["itemListElement"].map { |item| item["url"] }.first).to eq(property_url(amfora))
    end
  end

  describe "structured data" do
    before { get guide_path(guide_slug) }

    it "describes the ranked list as an ItemList" do
      list = json_ld("ItemList")
      expect(list).to include("@context" => "https://schema.org", "name" => "Best beachfront hotels in Hvar", "numberOfItems" => 4)
      expect(list["itemListElement"].map { |item| item.values_at("@type", "position", "url", "name") }).to eq([
        [ "ListItem", 1, property_url(amfora), "Hotel Amfora" ], [ "ListItem", 2, property_url(palace), "Palace Hotel" ],
        [ "ListItem", 3, property_url(villa), "Villa Across" ], [ "ListItem", 4, property_url(rooms), "Rooms Uphill" ]
      ])
    end

    it "marks up the questions and answers shown as an FAQPage" do
      faq = json_ld("FAQPage")
      questions = document.css(".guide-faq h3").map(&:text)
      answers = document.css(".guide-faq p").map(&:text)
      expect(faq["@context"]).to eq("https://schema.org")
      expect(faq["mainEntity"]).to all(include("@type" => "Question", "acceptedAnswer" => hash_including("@type" => "Answer")))
      expect(faq["mainEntity"].map { |q| [ q["name"], q.dig("acceptedAnswer", "text") ] }).to eq(questions.zip(answers))
    end

    it "gives the path from home to the guide as a BreadcrumbList" do
      crumbs = json_ld("BreadcrumbList")["itemListElement"]
      expect(crumbs.map { |crumb| crumb["item"] }).to eq([
        root_url, country_url(Country.new("HR")), destination_url(destination), guide_url(guide_slug)
      ])
      expect(crumbs.last).to include("position" => 4, "name" => "Best beachfront hotels in Hvar")
    end
  end

  describe "when it cannot be shown" do
    it "is not found for an unknown guide" do
      get guide_path("best-hotels-in-narnia")

      expect(response).to have_http_status(:not_found)
    end

    it "is not found when its destination does not exist or is not published" do
      get guide_path("ibiza-beachfront-hotels")
      expect(response).to have_http_status(:not_found)

      destination.update!(published: false)
      get guide_path(guide_slug)
      expect(response).to have_http_status(:not_found)
    end

    it "is not found, linked or in the sitemap when its destination lists nothing" do
      Property.where(destination:).update_all(hidden_at: Time.current)

      get guide_path(guide_slug)
      expect(response).to have_http_status(:not_found)

      get destination_path(destination)
      expect(response.body).not_to include(guide_path(guide_slug))
      get sitemap_path
      expect(response.body).not_to include(guide_url(guide_slug))
    end
  end

  describe "a Greek guide" do
    let(:chania) { create(:destination, name: "Chania Coast", slug: "chania-coast", country_code: "GR", sea_name: "Sea of Crete") }

    before do
      create(:property, :direct, destination: chania, name: "Hotel Kymata", distance_to_water_m: 12)
      create(:property, :near, destination: chania, name: "Studios Across", distance_to_water_m: 40, crosses_road: true)
    end

    it "ranks the destination's stays with its own copy and is linked from the Greece page and the sitemap" do
      get guide_path("chania-beachfront-hotels")

      expect(response).to have_http_status(:ok)
      expect(document.at_css("title").text).to eq("Chania beachfront hotels: which are really on the beach · StepsFrom")
      expect(document.css("h1").map(&:text)).to eq([ "Chania Coast hotels on the beach, measured" ])
      expect(document.at_css(".guide-intro").text.squish)
        .to include("shoreline of the Sea of Crete", "We have measured 2 places to stay on the Chania Coast that pass, 1 of them verified beachfront")
      expect(document.css(".guide-ranking__list .property-card__name").map(&:text)).to eq([ "Hotel Kymata", "Studios Across" ])

      get country_path(Country.new("GR"))
      expect(document.css(".guide-links a").map { |a| a["href"] }).to eq([ guide_path("chania-beachfront-hotels") ])

      get sitemap_path
      expect(response.body).to include(guide_url("chania-beachfront-hotels"))
    end
  end

  describe "links and sitemap" do
    it "is linked from its destination and country pages" do
      [ destination_path(destination), country_path(Country.new("HR")) ].each do |path|
        get path

        link = document.at_css(".guide-links a[href='#{guide_path(guide_slug)}']")
        expect(link&.text).to eq("Guide: the best beachfront hotels in Hvar"), path
      end
    end

    it "lists only the guides of the page's own destination" do
      makarska = create(:destination, name: "Makarska Riviera")
      create(:property, :direct, destination: makarska)

      get destination_path(destination)
      expect(document.css(".guide-links a").map { |a| a["href"] }).to eq([ guide_path(guide_slug) ])

      get country_path(Country.new("HR"))
      expect(document.css(".guide-links a").map { |a| a["href"] })
        .to contain_exactly(guide_path(guide_slug), guide_path("makarska-hotels-on-the-beach"))
    end

    it "is in the sitemap after the home page, dated by its newest listed change" do
      amfora.update_columns(updated_at: Time.utc(2026, 9, 1, 8))
      [ palace, villa, rooms ].each { |property| property.update_columns(updated_at: Time.utc(2026, 8, 1)) }
      Verification.update_all(updated_at: Time.utc(2026, 8, 1))
      palace.waterfront.update_columns(updated_at: Time.utc(2026, 10, 2, 9))

      get sitemap_path

      urls = Nokogiri::XML(response.body).remove_namespaces!.css("url")
      expect(urls.map { |url| url.at_css("loc").text }.first(3)).to eq([ root_url, guide_url(guide_slug), destination_url(destination) ])
      expect(urls[1].at_css("lastmod").text).to eq("2026-10-02T09:00:00Z")
    end

    it "lists every published guide in the sitemap" do
      Guide.all.map(&:destination_slug).uniq.excluding(destination.slug).each do |slug|
        create(:property, :direct, destination: create(:destination, name: slug.titleize, slug:))
      end

      get sitemap_path

      locs = Nokogiri::XML(response.body).remove_namespaces!.css("url loc").map(&:text)
      expect(Guide.published.size).to eq(Guide.all.size)
      expect(locs).to include(*Guide.all.map { |guide| guide_url(guide) })
    end

    it "dates a guide only by the stays it does not exclude" do
      [ amfora, palace, villa, rooms ].each { |property| property.update_columns(updated_at: Time.utc(2026, 8, 1)) }
      Verification.update_all(updated_at: Time.utc(2026, 8, 1))
      create(:property, :direct, destination:, slug: "diving-center").update_columns(updated_at: Time.utc(2026, 11, 1))
      config = Guide.config.merge(guide_slug => Guide.config.fetch(guide_slug).merge("exclude" => %w[diving-center]))
      allow(Guide).to receive(:config).and_return(config)

      get sitemap_path

      guide = Nokogiri::XML(response.body).remove_namespaces!.css("url").find { |url| url.at_css("loc").text == guide_url(guide_slug) }
      expect(guide.at_css("lastmod").text).to eq("2026-08-01T00:00:00Z")
    end

    it "dates a guide only by the kinds it ranks" do
      [ amfora, palace, villa, rooms ].each { |property| property.update_columns(updated_at: Time.utc(2026, 8, 1)) }
      Verification.update_all(updated_at: Time.utc(2026, 8, 1))
      create(:property, :direct, destination:, kind: "hostel").update_columns(updated_at: Time.utc(2026, 11, 1))

      get sitemap_path

      guide = Nokogiri::XML(response.body).remove_namespaces!.css("url").find { |url| url.at_css("loc").text == guide_url(guide_slug) }
      expect(guide.at_css("lastmod").text).to eq("2026-08-01T00:00:00Z")
    end
  end
end
