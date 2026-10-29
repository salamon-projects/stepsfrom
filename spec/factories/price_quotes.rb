FactoryBot.define do
  factory :price_quote do
    listing
    check_in { Date.current + 30 }
    check_out { Date.current + 33 }
    adults { 2 }
    total_cents { 30_000 }
    currency { "EUR" }
    source { "fake" }
    fetched_at { Time.current }
    expires_at { 6.hours.from_now }
  end
end
