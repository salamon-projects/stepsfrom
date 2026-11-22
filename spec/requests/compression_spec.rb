require "rails_helper"

RSpec.describe "Response compression" do
  it "gzips pages for clients that accept it" do
    get how_we_verify_path, headers: { "Accept-Encoding" => "gzip" }

    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Encoding"]).to eq("gzip")
    expect(Zlib.gunzip(response.body)).to include("</html>")
  end

  it "sends plain pages to clients that don't" do
    get how_we_verify_path

    expect(response.headers["Content-Encoding"]).to be_nil
    expect(response.body).to include("</html>")
  end

  it "gzips files from public/" do
    get "/icon.svg", headers: { "Accept-Encoding" => "gzip" }

    expect(response.headers["Content-Encoding"]).to eq("gzip")
  end

  it "leaves already-compressed images alone" do
    get "/og-image.jpg", headers: { "Accept-Encoding" => "gzip" }

    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Encoding"]).to be_nil
  end
end
