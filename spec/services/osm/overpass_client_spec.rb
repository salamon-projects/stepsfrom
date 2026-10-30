require "rails_helper"

RSpec.describe Osm::OverpassClient do
  let(:url) { "https://overpass.test/api/interpreter" }
  let(:backup) { "https://overpass-backup.test/api/interpreter" }
  let(:waits) { [] }
  let(:client) { described_class.new(urls: [ url, backup ], backoff: 10, attempts: 3, sleeper: ->(s) { waits << s }) }
  let(:body) { { elements: [ { type: "node", id: 1, lat: 43.3, lon: 17.0, tags: { name: "X" } } ] }.to_json }

  it "posts the query and parses elements" do
    stub = stub_request(:post, url).with(body: { data: "[out:json];node(1);out geom;" }).to_return(status: 200, body:)

    elements = client.query("[out:json];node(1);out geom;")

    expect(stub).to have_been_requested
    expect(elements.first).to have_attributes(type: "node", id: 1, tags: { "name" => "X" })
    expect(waits).to be_empty
  end

  it "retries a busy server on the next instance after waiting" do
    stub_request(:post, url).to_return(status: 502, body: "at capacity")
    stub_request(:post, backup).to_return(status: 200, body:)

    expect(client.query("x").size).to eq(1)
    expect(waits).to eq([ 10 ])
  end

  it "retries timeouts and gives up after the last attempt with growing waits" do
    stub_request(:post, url).to_timeout
    stub_request(:post, backup).to_return(status: 429, body: "rate limited")

    expect { client.query("x") }.to raise_error(Osm::OverpassClient::Error, /gave up after 3 attempts/)
    expect(waits).to eq([ 10, 20 ])
  end

  it "does not retry a bad query" do
    stub_request(:post, url).to_return(status: 400, body: "syntax error")

    expect { client.query("x") }.to raise_error(Osm::OverpassClient::Error, /400/)
    expect(waits).to be_empty
  end

  it "raises on malformed responses" do
    stub_request(:post, url).to_return(status: 200, body: "<html>")

    expect { client.query("x") }.to raise_error(Osm::OverpassClient::Error, /Unexpected/)
  end

  it "reads instances from the environment" do
    stub_const("ENV", ENV.to_h.merge("OVERPASS_URLS" => "https://a.test/api/interpreter, https://b.test/api/interpreter"))

    expect(described_class.configured_urls).to eq(%w[https://a.test/api/interpreter https://b.test/api/interpreter])
  end
end
