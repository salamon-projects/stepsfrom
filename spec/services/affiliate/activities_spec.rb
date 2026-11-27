require "rails_helper"

RSpec.describe Affiliate::Activities do
  let(:destination) { build(:destination, name: "Hvar", slug: "hvar") }

  def with_env(values)
    blank = { "GETYOURGUIDE_PARTNER_ID" => "", "VIATOR_PID" => "", "VIATOR_MCID" => "" }
    stub_const("ENV", ENV.to_h.merge(blank, values))
  end

  def query(url)
    URI.decode_www_form(URI.parse(url).query).to_h
  end

  describe ".configured" do
    it "is empty when no ids are set" do
      with_env({})

      expect(described_class.configured).to be_empty
    end

    it "has GetYourGuide alone once its partner id is set" do
      with_env("GETYOURGUIDE_PARTNER_ID" => "GYG1")

      expect(described_class.configured.map(&:key)).to eq(%w[getyourguide])
    end

    it "leaves Viator out unless both its pid and mcid are set" do
      with_env("VIATOR_PID" => "P00012345")
      expect(described_class.configured).to be_empty

      with_env("VIATOR_MCID" => "42383")
      expect(described_class.configured).to be_empty

      with_env("VIATOR_PID" => "P00012345", "VIATOR_MCID" => "  ")
      expect(described_class.configured).to be_empty

      with_env("VIATOR_PID" => "P00012345", "VIATOR_MCID" => "42383")
      expect(described_class.configured.map(&:key)).to eq(%w[viator])
    end

    it "has both, GetYourGuide first, when everything is set" do
      with_env("GETYOURGUIDE_PARTNER_ID" => "GYG1", "VIATOR_PID" => "P00012345", "VIATOR_MCID" => "42383")

      expect(described_class.configured.map(&:name)).to eq(%w[GetYourGuide Viator])
    end
  end

  describe "URLs" do
    before { with_env("GETYOURGUIDE_PARTNER_ID" => " GYG1 ", "VIATOR_PID" => "P00012345", "VIATOR_MCID" => "42383") }

    it "searches GetYourGuide for the destination with our partner id" do
      url = described_class.find_configured("getyourguide").url(destination)

      expect(url).to start_with("https://www.getyourguide.com/s/?")
      expect(query(url)).to eq("q" => "Hvar", "partner_id" => "GYG1")
    end

    it "searches Viator with pid, mcid, medium=link and the slug as campaign" do
      url = described_class.find_configured("viator").url(destination)

      expect(url).to start_with("https://www.viator.com/searchResults/all?")
      expect(query(url)).to eq("text" => "Hvar", "pid" => "P00012345", "mcid" => "42383", "medium" => "link",
                               "campaign" => "hvar")
    end

    it "searches for a configured term where the destination's name would search poorly" do
      zakynthos = build(:destination, name: "Zakynthos south", slug: "zakynthos-south")

      expect(query(described_class.find_configured("viator").url(zakynthos))).to include("text" => "Zakynthos")
      expect(described_class.search_term(build(:destination, name: "Lloret & Tossa", slug: "lloret-tossa")))
        .to eq("Lloret & Tossa")
    end

    it "encodes the search text" do
      url = described_class.find_configured("getyourguide").url(build(:destination, name: "Brač & Hvar", slug: "brac-hvar"))

      expect(url).to include("q=Bra%C4%8D+%26+Hvar")
    end
  end
end
