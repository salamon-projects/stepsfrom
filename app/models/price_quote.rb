# A cached price for one listing and stay, delivered by a Prices provider.
class PriceQuote < ApplicationRecord
  belongs_to :listing

  validates :check_in, :check_out, :adults, :total_cents, :currency, :source, :fetched_at, :expires_at, presence: true
  validates :total_cents, numericality: { only_integer: true, greater_than: 0 }

  scope :fresh, -> { where("price_quotes.expires_at > ?", Time.current) }
  scope :for_stay, ->(stay) { where(check_in: stay.check_in, check_out: stay.check_out, adults: stay.adults) }

  def total
    total_cents / 100.0
  end
end
