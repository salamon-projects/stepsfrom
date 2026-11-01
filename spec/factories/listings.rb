FactoryBot.define do
  factory :listing do
    property
    provider { "booking" }
    sequence(:url) { |n| "https://www.booking.com/hotel/hr/sample-#{n}.html" }

    trait :expedia do
      provider { "expedia" }
      sequence(:url) { |n| "https://www.expedia.com/Makarska-Hotels-Sample.h#{n}.Hotel-Information" }
    end

    trait :vrbo do
      provider { "vrbo" }
      sequence(:url) { |n| "https://www.vrbo.com/#{1_000_000 + n}" }
    end

    trait :agoda do
      provider { "agoda" }
      sequence(:url) { |n| "https://www.agoda.com/sample-#{n}/hotel/makarska-hr.html" }
    end
  end
end
