require "rails_helper"

RSpec.describe Guide do
  let(:destination) { create(:destination, name: "Hvar", sea_name: "Adriatic Sea") }

  describe "config/guides.yml" do
    it "has the initial guides, each for its destination" do
      expect(described_class.all.to_h { |guide| [ guide.slug, guide.destination_slug ] }).to include(
        "hvar-beachfront-hotels" => "hvar", "makarska-hotels-on-the-beach" => "makarska-riviera",
        "ibiza-beachfront-hotels" => "ibiza"
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
