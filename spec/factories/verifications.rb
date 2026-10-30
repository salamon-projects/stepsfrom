FactoryBot.define do
  factory :waterfront_verification, class: "Verifications::Waterfront" do
    property
    category { "direct" }
    distance_m { 20 }
    measured_at { Time.current }
  end
end
