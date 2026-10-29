require "rails_helper"

RSpec.describe "Admin" do
  let(:auth) { { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin") } }
  let(:destination) { create(:destination, name: "Makarska Riviera") }

  it "requires basic auth" do
    get admin_properties_path

    expect(response).to have_http_status(:unauthorized)

    get admin_properties_path, headers: { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "wrong") }
    expect(response).to have_http_status(:unauthorized)
  end

  it "uses configured credentials instead of the development default" do
    stub_const("ENV", ENV.to_h.merge("ADMIN_USER" => "editor", "ADMIN_PASSWORD" => "s3cret"))

    get admin_properties_path, headers: auth
    expect(response).to have_http_status(:unauthorized)

    get admin_properties_path, headers: { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("editor", "s3cret") }
    expect(response).to have_http_status(:ok)
  end

  describe "properties" do
    let!(:candidate) { create(:property, :direct, destination:, name: "Hotel Candidate") }
    let!(:approved) { create(:property, :approved, :near, destination:, name: "Hotel Approved") }
    let!(:inland) { create(:property, :not_waterfront, destination:, name: "Hotel Inland") }

    it "shows the review queue by default" do
      get admin_properties_path, headers: auth

      expect(response.body).to include("Hotel Candidate")
      expect(response.body).not_to include("Hotel Approved", "Hotel Inland")
    end

    it "lists booking-site claims that contradict the measurement" do
      create(:listing, property: inland, claims_beachfront: true)

      get admin_properties_path(view: "conflicts"), headers: auth

      expect(response.body).to include("Hotel Inland", "OTA says beachfront")
      expect(response.body).not_to include("Hotel Candidate")
    end

    it "approves and rejects with a note" do
      post approve_admin_property_path(candidate), params: { qa_note: "Checked on satellite." }, headers: auth

      expect(candidate.reload).to have_attributes(qa_status: "approved", qa_note: "Checked on satellite.")
      expect(Property.published).to include(candidate)

      post reject_admin_property_path(approved), headers: auth
      expect(approved.reload.qa_status).to eq("rejected")
    end

    it "creates a property and measures it straight away" do
      create(:water_feature, geom: east_west_line(north_m: 30))
      lon, lat = offset

      post admin_properties_path, headers: auth, params: {
        property: { destination_id: destination.id, name: "Villa Manual", kind: "villa", latitude: lat, longitude: lon }
      }

      property = Property.find_by!(name: "Villa Manual")
      expect(response).to redirect_to(admin_property_path(property))
      expect(property).to have_attributes(waterfront_category: "direct", qa_status: "pending")
      expect(property.distance_to_water_m).to be_within(1).of(30)
    end

    it "re-measures after a coordinate correction" do
      create(:water_feature, geom: east_west_line(north_m: 30))
      lon, lat = offset(north_m: -400)

      patch admin_property_path(candidate), headers: auth, params: { property: { latitude: lat, longitude: lon } }

      expect(candidate.reload).to have_attributes(waterfront_category: "not_waterfront")
    end

    it "shows the measurement and listings" do
      create(:listing, property: candidate, claims_beachfront: true)

      get admin_property_path(candidate), headers: auth

      expect(response.body).to include("Measurement", "Booking.com", "data-map=")
    end

    it "re-renders the form on invalid input" do
      post admin_properties_path, headers: auth, params: { property: { destination_id: destination.id, name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("problem")
    end
  end

  describe "listings" do
    let(:property) { create(:property, :direct, destination:) }

    it "adds a listing and rejects foreign URLs" do
      post admin_property_listings_path(property), headers: auth, params: {
        listing: { provider: "agoda", url: "https://www.agoda.com/x/hotel/y.html", claims_beachfront: "true", active: "1" }
      }
      expect(property.listings.sole).to have_attributes(provider: "agoda", claims_beachfront: true)

      post admin_property_listings_path(property), headers: auth, params: {
        listing: { provider: "booking", url: "https://evil.example/hotel", active: "1" }
      }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("is not a Booking.com address")
    end

    it "flags a reported position far from ours" do
      lon, lat = offset(north_m: 400)

      perform_enqueued_jobs do
        post admin_property_listings_path(property), headers: auth, params: {
          listing: { provider: "booking", url: "https://www.booking.com/hotel/hr/x.html", reported_latitude: lat,
                     reported_longitude: lon, active: "1" }
        }
      end

      expect(property.reload.coord_mismatch_m).to be_within(1).of(400)
    end
  end

  describe "destinations" do
    it "creates a destination from a bounding box" do
      post admin_destinations_path, headers: auth, params: {
        destination: { name: "Zadar Riviera", country_code: "HR", sea_name: "Adriatic Sea",
                       south: "44.0", west: "15.1", north: "44.2", east: "15.4", zoom: "11", published: "1" }
      }

      expect(Destination.find_by!(slug: "zadar-riviera").bbox).to eq([ 44.0, 15.1, 44.2, 15.4 ])
    end

    it "queues an OSM import" do
      expect {
        post import_admin_destination_path(destination), headers: auth
      }.to have_enqueued_job(OsmImportJob).with(destination.id)
    end

    it "refuses to delete a destination that has properties" do
      create(:property, destination:)

      delete admin_destination_path(destination), headers: auth

      expect(Destination.exists?(destination.id)).to be(true)
      expect(flash[:alert]).to be_present
    end
  end
end
