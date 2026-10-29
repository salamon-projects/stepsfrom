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
  end
end
