# One visitor click-out to a booking site. No IP address or user identifier is
# stored.
class OutboundClick < ApplicationRecord
  belongs_to :listing, optional: true
  belongs_to :property, optional: true

  validates :provider, presence: true
end
