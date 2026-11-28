require "rails_helper"

# Kassandra's area is the peninsula, not the rectangle around it, which also
# covers Sithonia's west coast. Properties assigned to Kassandra but outside
# the peninsula stay in admin and leave every public page.
RSpec.describe "Destination areas" do
  let(:kassandra) { create(:destination, :kassandra) }
  let!(:inside) { kassandra_property(:kallithea, destination: kassandra, name: "Kallithea Beach Hotel") }
  let!(:porto_carras) { kassandra_property(:porto_carras, destination: kassandra, name: "Porto Carras Grand Resort") }
  let!(:vourvourou) { kassandra_property(:vourvourou, destination: kassandra, name: "Vourvourou Rooms") }

  it "has no public page for a property outside its destination's area" do
    get property_path(inside)
    expect(response).to have_http_status(:ok)

    [ porto_carras, vourvourou ].each do |property|
      get property_path(property)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "leaves them out of the destination, country and home pages and their counts" do
    get destination_path(kassandra)
    expect(response.body).to include("Kallithea Beach Hotel")
    expect(response.body).not_to include("Porto Carras", "Vourvourou")

    get country_path(Country.new("GR"))
    expect(response.body).to include("Kallithea Beach Hotel")
    expect(response.body).not_to include("Porto Carras", "Vourvourou")
    expect(controller.instance_variable_get(:@listed_counts)).to eq(kassandra.id => 1)

    get root_path
    expect(controller.instance_variable_get(:@listed_counts)).to eq(kassandra.id => 1)
  end

  it "leaves them out of the sitemap" do
    get sitemap_path

    expect(response.body).to include(property_url(inside))
    expect(response.body).not_to include(property_url(porto_carras), property_url(vourvourou))
  end

  it "leaves them out of the Kassandra guide's list and figures" do
    guide = Guide.find_published("kassandra-beachfront-hotels")
    expect(guide.properties).to eq([ inside ])
    expect(guide.facts).to include(listed_count: 1, direct: 1, closest_name: "Kallithea Beach Hotel")

    get guide_path(guide)
    expect(response.body).to include("Kallithea Beach Hotel")
    expect(response.body).not_to include("Porto Carras", "Vourvourou")
  end

  it "still shows them in admin, saying why they are not listed" do
    sign_in_admin

    get admin_property_path(porto_carras)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Outside Kassandra")
  end

  describe "editing the destination in admin" do
    let(:peninsula) { Destination.configured_area("kassandra") }

    def form_values(changes = {})
      { name: "Kassandra", country_code: "GR", south: "39.9", west: "23.28", north: "40.22", east: "23.78" }.merge(changes)
    end

    before { sign_in_admin }

    it "warns that changing the bounding box replaces the area" do
      get edit_admin_destination_path(kassandra)

      expect(response.body).to include("is not a rectangle")
    end

    it "keeps the area when the form is saved with the bounding box unchanged" do
      patch admin_destination_path(kassandra), params: { destination: form_values(summary: "The first finger of Halkidiki.") }

      expect(kassandra.reload.summary).to eq("The first finger of Halkidiki.")
      expect(Destination.find(kassandra.id).area).to eq(peninsula)
      expect(Property.published).to contain_exactly(inside)
    end

    it "replaces the area with the rectangle when the bounding box is changed" do
      patch admin_destination_path(kassandra), params: { destination: form_values(north: "40.25", east: "23.80") }

      expect(Destination.find(kassandra.id)).to be_rectangular
      expect(Property.published).to contain_exactly(inside, porto_carras, vourvourou)
    end
  end
end
