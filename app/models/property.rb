class Property < ApplicationRecord
  include Sluggable

  KINDS = %w[hotel resort apartment guest_house hostel motel villa chalet camp_site].freeze
  CATEGORIES = %w[direct near walkable not_waterfront unknown].freeze
  LISTED_CATEGORIES = %w[direct near walkable].freeze
  QA_STATUSES = %w[pending approved rejected].freeze
  WEBSITE_FORMAT = %r{\Ahttps?://[^\s]+\z}i

  belongs_to :destination
  belongs_to :water_feature, optional: true
  has_many :listings, dependent: :destroy
  has_many :active_listings, -> { active }, class_name: "Listing", inverse_of: :property
  has_many :price_quotes, through: :active_listings

  enum :kind, KINDS.index_by(&:itself), validate: true
  enum :waterfront_category, CATEGORIES.index_by(&:itself), prefix: :waterfront, validate: true
  enum :qa_status, QA_STATUSES.index_by(&:itself), prefix: :qa, validate: true

  attribute :latitude, :float
  attribute :longitude, :float

  before_validation :build_lonlat_from_coordinates, if: :coordinates_entered?
  after_initialize :load_coordinates, if: -> { has_attribute?(:lonlat) && lonlat.present? && latitude.nil? }

  validates :name, :lonlat, presence: true
  validates :stars, numericality: { only_integer: true, in: 1..5 }, allow_nil: true
  validates :latitude, numericality: { in: -90..90 }, allow_nil: true
  validates :longitude, numericality: { in: -180..180 }, allow_nil: true
  validates :website, format: { with: WEBSITE_FORMAT }, allow_blank: true

  after_commit :enqueue_classification, on: %i[create update], if: :geometry_changed?

  scope :published, -> { qa_approved.where(waterfront_category: LISTED_CATEGORIES) }

  # Best waterfront first, then the shortest measured distance.
  scope :by_waterfront, -> {
    order(
      Arel.sql(sanitize_sql_array([ "array_position(ARRAY[?]::varchar[], properties.waterfront_category)", CATEGORIES ])),
      :distance_to_water_m, :name
    )
  }

  # Properties that an OTA labels beachfront although our measurement does not
  # support it.
  scope :beachfront_claim_conflicts, -> {
    where(id: Listing.where(claims_beachfront: true).select(:property_id))
      .where(waterfront_category: %w[not_waterfront walkable])
  }

  scope :with_coordinate_mismatch, -> {
    where("properties.coord_mismatch_m > ?", Waterfront.config.fetch(:coordinate_mismatch_m))
  }

  def listed?
    qa_approved? && waterfront_category.in?(LISTED_CATEGORIES)
  end

  def lonlat=(value)
    super
    load_coordinates if lonlat
  end

  def coordinate_mismatch?
    coord_mismatch_m.to_i > Waterfront.config.fetch(:coordinate_mismatch_m)
  end

  # "the Adriatic Sea", "Lake Bled", or a generic "the sea".
  def water_display_name
    return water_name if water_name.present?
    return "the #{destination.sea_name}" if destination.sea_name.present? && (water_kind.nil? || water_kind == "sea")

    I18n.t("properties.water_kinds.#{water_kind || 'sea'}")
  end

  private

  def coordinates_entered?
    (attribute_changed?(:latitude) || attribute_changed?(:longitude)) && latitude.present? && longitude.present?
  end

  def build_lonlat_from_coordinates
    point = Geo.point(lon: longitude, lat: latitude)
    self.lonlat = point unless lonlat && lonlat.x == point.x && lonlat.y == point.y
  end

  def load_coordinates
    self.latitude = lonlat.y
    self.longitude = lonlat.x
    clear_attribute_changes(%i[latitude longitude])
  end

  def geometry_changed?
    saved_change_to_lonlat? || saved_change_to_footprint?
  end

  def enqueue_classification
    ClassifyPropertyJob.perform_later(id)
  end
end
