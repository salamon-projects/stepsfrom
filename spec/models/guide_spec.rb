require "rails_helper"

RSpec.describe Guide do
  let(:destination) { create(:destination, name: "Hvar", sea_name: "Adriatic Sea") }

  describe "config/guides.yml" do
    it "has the initial guides, each for its destination" do
      expect(described_class.all.to_h { |guide| [ guide.slug, guide.destination_slug ] }).to include(
        "hvar-beachfront-hotels" => "hvar", "makarska-hotels-on-the-beach" => "makarska-riviera",
        "ibiza-beachfront-hotels" => "ibiza", "kassandra-beachfront-hotels" => "kassandra",
        "chania-beachfront-hotels" => "chania-coast", "zakynthos-beachfront-hotels" => "zakynthos-south",
        "rhodes-beachfront-hotels" => "rhodes-east-coast"
      )
    end

    it "gives every guide a unique title, heading and URL-safe slug" do
      guides = described_class.all
      expect(guides.map(&:title).uniq.size).to eq(guides.size)
      expect(guides.map(&:heading).uniq.size).to eq(guides.size)
      expect(guides.map(&:slug)).to all(match(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/))
    end

    it "fills every placeholder in every guide's copy from the data" do
      described_class.all.each do |guide|
        place = create(:destination, name: guide.destination_slug.titleize, slug: guide.destination_slug)
        create(:property, :direct, destination: place)
        guide = described_class.find_published(guide.slug)

        texts = [ guide.description, *guide.intro, *guide.faq.flatten ]
        expect(texts).to all(be_present)
        expect(texts.join).not_to include("%{")
        expect(guide.intro.join(" ").split.size).to be_between(150, 250), "#{guide.slug} intro length"
        expect(guide.faq.size).to be_between(3, 5)
      end
    end
  end

  describe "kinds" do
    def guide_with(kinds)
      described_class.new("hvar-beachfront-hotels", described_class.config.fetch("hvar-beachfront-hotels").merge("kinds" => kinds))
    end

    it "leaves campsites and hostels out of every configured guide" do
      described_class.all.each do |guide|
        expect(guide.kinds).to match_array(Property::KINDS - %w[camp_site hostel]), guide.slug
      end
    end

    it "ranks and counts only the guide's kinds" do
      create(:property, :direct, destination:, kind: "camp_site", name: "Kamp Dolac", distance_to_water_m: 2)
      create(:property, :near, destination:, kind: "hostel", name: "Hostel Riva", distance_to_water_m: 4)
      hotel = create(:property, :direct, destination:, kind: "hotel", name: "Hotel Amfora", distance_to_water_m: 30)
      villa = create(:property, :walkable, destination:, kind: "villa", name: "Villa Mare", distance_to_water_m: 90)
      guide = described_class.find_published("hvar-beachfront-hotels")

      expect(guide.properties).to eq([ hotel, villa ])
      expect(guide.facts).to include(listed: "2 places to stay", listed_count: 2, direct: 1, near: 0, walkable: 1,
                                     shown: 2, closest_name: "Hotel Amfora", closest_m: 30)
      expect(guide.faq.flatten.join).not_to include("Kamp Dolac")
    end

    it "ranks every listed kind when the guide names none" do
      hostel = create(:property, :direct, destination:, kind: "hostel", distance_to_water_m: 2)

      guide = guide_with(nil)

      expect(guide.properties).to eq([ hostel ])
      expect(guide.facts).to include(listed_count: 1, closest_m: 2)
    end

    it "never ranks or counts a kind kept off the site, even without a kinds filter" do
      create(:property, :direct, destination:, kind: "camp_site", name: "Kamp Dolac", distance_to_water_m: 1)
      hotel = create(:property, :direct, destination:, kind: "hotel", distance_to_water_m: 20)

      guide = guide_with(nil)

      expect(guide.properties).to eq([ hotel ])
      expect(guide.facts).to include(listed_count: 1, direct: 1, closest_m: 20)
      expect(guide.faq.flatten.join).not_to include("Kamp Dolac")
    end

    it "is unpublished when nothing of its kinds is listed" do
      create(:property, :direct, destination:, kind: "camp_site")
      create(:property, :direct, destination:, kind: "hostel")

      expect(described_class.find_published("hvar-beachfront-hotels")).to be_nil
      expect(described_class.published.map(&:slug)).not_to include("hvar-beachfront-hotels")
      expect(described_class.for_destinations([ destination ])).to be_empty
      expect(guide_with([])).not_to be_published
    end

    it "rejects a kind that is not a property kind" do
      expect { guide_with(%w[hotel castle]) }.to raise_error(ArgumentError, /castle/)
    end
  end

  describe "exclude" do
    def guide_excluding(slugs)
      described_class.new("hvar-beachfront-hotels", described_class.config.fetch("hvar-beachfront-hotels").merge("exclude" => slugs))
    end

    it "leaves the excluded properties out of the list and every figure, but not off the site" do
      diving = create(:property, :direct, destination:, name: "Diving Center", slug: "diving-center", distance_to_water_m: 1)
      hotel = create(:property, :direct, destination:, name: "Hotel Amfora", distance_to_water_m: 30)
      villa = create(:property, :near, destination:, name: "Villa Mare", distance_to_water_m: 12)
      guide = guide_excluding(%w[diving-center])

      expect(guide.properties).to eq([ hotel, villa ])
      expect(guide.facts).to include(listed: "2 places to stay", listed_count: 2, direct: 1, near: 1,
                                     shown: 2, closest_name: "Villa Mare", closest_m: 12)
      expect([ guide.description, *guide.faq.flatten ].join).not_to include("Diving Center")
      expect(guide.counts?(diving)).to be(false)
      expect(guide.counts?(hotel)).to be(true)
      expect(Property.published).to include(diving)
    end

    it "is unpublished when it excludes everything listed" do
      create(:property, :direct, destination:, slug: "diving-center")

      expect(guide_excluding(%w[diving-center])).not_to be_published
      expect(guide_excluding([])).to be_published
    end

    it "excludes nothing by default" do
      expect(described_class.all.find { |guide| guide.slug == "hvar-beachfront-hotels" }.exclude).to eq([])
      expect(guide_excluding(nil).exclude).to eq([])
    end
  end

  describe ".find_published" do
    it "finds a guide whose destination lists properties" do
      create(:property, :direct, destination:)

      expect(described_class.find_published("hvar-beachfront-hotels").destination).to eq(destination)
    end

    it "is nil for an unknown slug, a missing or unpublished destination, or one with nothing listed" do
      expect(described_class.find_published("nowhere")).to be_nil
      expect(described_class.find_published("hvar-beachfront-hotels")).to be_nil

      create(:property, :not_waterfront, destination:)
      create(:property, :direct, :hidden, destination:)
      expect(described_class.find_published("hvar-beachfront-hotels")).to be_nil

      create(:property, :direct, destination:)
      destination.update!(published: false)
      expect(described_class.find_published("hvar-beachfront-hotels")).to be_nil
    end
  end

  describe "#properties" do
    it "ranks verified beachfront first, then by distance, up to the limit" do
      walkable = create(:property, :walkable, destination:, distance_to_water_m: 120)
      near = create(:property, :near, destination:, distance_to_water_m: 15)
      far_direct = create(:property, :direct, destination:, distance_to_water_m: 40)
      close_direct = create(:property, :direct, destination:, distance_to_water_m: 5)
      create(:property, :not_waterfront, destination:)
      guide = described_class.find_published("hvar-beachfront-hotels")

      expect(guide.properties).to eq([ close_direct, far_direct, near, walkable ])

      stub_const("Guide::DEFAULT_LIMIT", 2)
      expect(described_class.find_published("hvar-beachfront-hotels").properties).to eq([ close_direct, far_direct ])
    end
  end

  describe "#facts" do
    it "counts the destination's listed stays and finds the closest" do
      create(:property, :direct, destination:, name: "Hotel Amfora", distance_to_water_m: 30)
      create(:property, :near, destination:, name: "Villa Mare", distance_to_water_m: 12)
      create(:property, :not_waterfront, destination:)

      facts = described_class.find_published("hvar-beachfront-hotels").facts

      expect(facts).to include(listed: "2 places to stay", listed_count: 2, direct: 1, near: 1, walkable: 0,
                               closest_name: "Villa Mare", closest_m: 12, closest: "12 m from the water",
                               sea: "the Adriatic Sea", direct_max_m: Waterfront.config.fetch(:direct_max_m))
    end

    it "says a stay measured at 0 m is right on the water" do
      create(:property, :direct, destination:, name: "Hotel Riva", distance_to_water_m: 0)

      guide = described_class.find_published("hvar-beachfront-hotels")

      expect(guide.facts).to include(closest_m: 0, closest: "right on the water", listed: "1 place to stay")
      expect(guide.description).to end_with("The closest is right on the water.")
    end
  end
end
