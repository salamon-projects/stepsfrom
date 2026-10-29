require "rails_helper"

RSpec.describe OsmImportJob do
  let(:destination) { create(:destination) }

  it "retries later when Overpass is unavailable" do
    allow(Osm::DestinationImport).to receive(:new).and_raise(Osm::OverpassClient::Error, "Overpass returned HTTP 429")

    expect { described_class.perform_now(destination.id) }.to have_enqueued_job(described_class).with(destination.id)
  end

  it "imports the destination" do
    import = instance_double(Osm::DestinationImport, call: { coastline: 1 })
    allow(Osm::DestinationImport).to receive(:new).with(destination).and_return(import)

    described_class.perform_now(destination.id)

    expect(import).to have_received(:call)
  end
end
