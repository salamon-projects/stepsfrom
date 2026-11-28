require "rails_helper"

RSpec.describe Transliteration do
  it "writes Greek names in Latin letters as on Greek road signs" do
    expect(described_class.from_greek("Ξενοδοχείο Ήλιος")).to eq("Xenodocheio Ilios")
    expect(described_class.from_greek("Βίλα Ρόδων")).to eq("Vila Rodon")
    expect(described_class.from_greek("Καλλιθέα")).to eq("Kallithea")
    expect(described_class.from_greek("Ουρανούπολη")).to eq("Ouranoupoli")
    expect(described_class.from_greek("Παραλία Ευαγγελίστρια")).to eq("Paralia Evangelistria")
  end

  it "leaves Latin words and digits alone" do
    expect(described_class.from_greek("Hotel Ήλιος 2")).to eq("Hotel Ilios 2")
  end

  it "tells Greek from Latin" do
    expect(described_class.greek?("Ήλιος")).to be(true)
    expect(described_class.greek?("Hôtel")).to be(false)
  end
end
