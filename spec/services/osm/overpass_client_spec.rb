require "rails_helper"

RSpec.describe Osm::OverpassClient do
  let(:url) { "https://overpass.test/api/interpreter" }
  let(:client) { described_class.new(url:) }

  it "posts the query and parses elements" do
    body = { elements: [ { type: "node", id: 1, lat: 43.3, lon: 17.0, tags: { name: "X" } } ] }.to_json
    stub = stub_request(:post, url).with(body: { data: "[out:json];node(1);out geom;" }).to_return(status: 200, body:)

    elements = client.query("[out:json];node(1);out geom;")

    expect(stub).to have_been_requested
    expect(elements.first).to have_attributes(type: "node", id: 1, tags: { "name" => "X" })
  end

  it "raises on HTTP errors" do
    stub_request(:post, url).to_return(status: 429, body: "rate limited")

    expect { client.query("x") }.to raise_error(Osm::OverpassClient::Error, /429/)
  end

  it "raises on malformed responses" do
    stub_request(:post, url).to_return(status: 200, body: "<html>")

    expect { client.query("x") }.to raise_error(Osm::OverpassClient::Error, /Unexpected/)
  end
end
