# A property's page on one booking site (OTA).
class Listing < ApplicationRecord
  belongs_to :property
  has_many :price_quotes, dependent: :delete_all
  has_many :outbound_clicks, dependent: :nullify

  # How StepsFrom made an automatic listing (see Affiliate::AutoListings);
  # nil for listings an admin entered.
  GENERATORS = %w[search stay22].freeze

  enum :provider, Affiliate::Provider.keys.index_by(&:itself), validate: true

  attribute :reported_latitude, :float
  attribute :reported_longitude, :float

  before_validation :build_reported_lonlat
  before_save :confirm_entered_listing
  after_initialize :load_reported_coordinates, if: -> { has_attribute?(:reported_lonlat) && reported_lonlat.present? && reported_latitude.nil? }

  validates :url, presence: true
  validates :provider, uniqueness: { scope: :property_id }
  validates :generator, inclusion: { in: GENERATORS }, allow_nil: true
  validate :url_belongs_to_provider

  after_commit :reclassify_property, if: :saved_change_to_reported_lonlat?

  scope :active, -> { where(active: true) }
  scope :unconfirmed, -> { where(confirmed_at: nil) }

  def provider_config
    Affiliate::Provider.find(provider)
  end

  def provider_name
    provider_config&.name || provider
  end

  def automatic?
    generator.present?
  end

  # Whether the link is known to open this property's own page. Automatic
  # links find it by name and position and may land on a search instead.
  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update!(confirmed_at: Time.current)
  end

  private

  # An admin entered (or rewrote) the URL, so it is the property's page.
  def confirm_entered_listing
    self.confirmed_at ||= Time.current unless automatic?
  end

  def build_reported_lonlat
    return unless attribute_changed?(:reported_latitude) || attribute_changed?(:reported_longitude)

    if reported_latitude.present? && reported_longitude.present?
      self.reported_lonlat = Geo.point(lon: reported_longitude, lat: reported_latitude)
    elsif reported_latitude.blank? && reported_longitude.blank?
      self.reported_lonlat = nil
    end
  end

  def load_reported_coordinates
    self.reported_latitude = reported_lonlat.y
    self.reported_longitude = reported_lonlat.x
    clear_attribute_changes(%i[reported_latitude reported_longitude])
  end

  def url_belongs_to_provider
    return if url.blank? || provider_config.nil?
    return if generator == "stay22" && Affiliate::Stay22.link?(url)

    errors.add(:url, :invalid_for_provider, provider: provider_name) unless provider_config.accepts_url?(url)
  end

  def reclassify_property
    ClassifyPropertyJob.perform_later(property_id)
  end
end
