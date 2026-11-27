require "rails_helper"

RSpec.describe "Guide routes" do
  it "routes /guides/:slug to the guide page" do
    expect(get: "/guides/hvar-beachfront-hotels").to route_to("guides#show", id: "hvar-beachfront-hotels")
  end

  it "has no guide index" do
    expect(get: "/guides").not_to be_routable
  end
end
