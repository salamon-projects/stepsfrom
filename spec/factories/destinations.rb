FactoryBot.define do
  factory :destination do
    sequence(:name) { |n| "Test Riviera #{n}" }
    country_code { "HR" }
    sea_name { "Adriatic Sea" }
    south { 43.25 }
    west { 16.95 }
    north { 43.35 }
    east { 17.10 }
    published { true }

    # The Kassandra peninsula polygon from config/destination_areas.yml
    # (see KassandraHelpers for places inside and outside it).
    trait :kassandra do
      name { "Kassandra" }
      country_code { "GR" }
      sea_name { "Aegean Sea" }
      south { nil }
      west { nil }
      north { nil }
      east { nil }
      area { Destination.configured_area("kassandra") }
    end
  end
end
