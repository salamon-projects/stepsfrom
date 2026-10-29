FactoryBot.define do
  factory :property do
    destination
    sequence(:name) { |n| "Sample Hotel #{n}" }
    kind { "hotel" }
    latitude { GeoHelpers::BASE_LAT }
    longitude { GeoHelpers::BASE_LON }

    trait :approved do
      qa_status { "approved" }
    end

    trait :direct do
      waterfront_category { "direct" }
      distance_to_water_m { 20 }
      water_kind { "sea" }
    end

    trait :near do
      waterfront_category { "near" }
      distance_to_water_m { 80 }
      water_kind { "sea" }
    end

    trait :walkable do
      waterfront_category { "walkable" }
      distance_to_water_m { 250 }
      water_kind { "sea" }
    end

    trait :not_waterfront do
      waterfront_category { "not_waterfront" }
      distance_to_water_m { 700 }
    end
  end
end
