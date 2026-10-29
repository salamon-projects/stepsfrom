# A property's page on one booking site (OTA).
class Listing < ApplicationRecord
  belongs_to :property
  has_many :price_quotes, dependent: :delete_all
  has_many :outbound_clicks, dependent: :nullify

  enum :provider, Affiliate::Provider.keys.index_by(&:itself), validate: true

  attribute :reported_latitude, :float
  attribute :reported_longitude, :float

  before_validation :build_reported_lonlat
  after_initialize :load_reported_coordinates, if: -> { reported_lonlat.present? && reported_latitude.nil? }

  validates :url, presence: true
  validates :provider, uniqueness: { scope: :property_id }
  validate :url_belongs_to_provider

  after_commit :reclassify_property, if: :saved_change_to_reported_lonlat?

  scope :active, -> { where(active: true) }

  def provider_config
    Affiliate::Provider.find(provider)
  end

  def provider_name
    provider_config&.name || provider
  end

  private

  def build_reported_lonlat
    if reported_latitude.present? && reported_longitude.present?
      point = Geo.point(lon: reported_longitude, lat: reported_latitude)
      self.reported_lonlat = point unless reported_lonlat && reported_lonlat.x == point.x && reported_lonlat.y == point.y
    elsif reported_latitude.blank? && reported_longitude.blank? && will_save_change_to_attribute?(:reported_latitude)
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

    errors.add(:url, :invalid_for_provider, provider: provider_name) unless provider_config.accepts_url?(url)
  end

  def reclassify_property
    ClassifyPropertyJob.perform_later(property_id)
  end
end
