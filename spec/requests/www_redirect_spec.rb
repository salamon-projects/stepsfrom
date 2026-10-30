require "rails_helper"

RSpec.describe "www redirect" do
  it "sends www.stepsfrom.com to the bare domain, keeping path and query" do
    host! "www.stepsfrom.com"

    get "/how-we-verify?ref=ad"

    expect(response).to have_http_status(:moved_permanently)
    expect(response.location).to eq("http://stepsfrom.com/how-we-verify?ref=ad")
  end

  it "serves the bare domain normally" do
    host! "stepsfrom.com"

    get how_we_verify_path

    expect(response).to have_http_status(:ok)
  end
end
