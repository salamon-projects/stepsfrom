class Property < ApplicationRecord
  include Sluggable

  KINDS = %w[hotel resort apartment guest_house hostel motel villa chalet camp_site].freeze
  WEBSITE_FORMAT = %r{\Ahttps?://[^\s]+\z}i

  belongs_to :destination
  has_many :verifications, dependent: :destroy
  has_one :waterfront, class_name: "Verifications::Waterfront", inverse_of: :property
  has_many :listings, dependent: :destroy
  has_many :active_listings, -> { active }, class_name: "Listing", inverse_of: :property
  has_many :price_quotes, through: :active_listings

  enum :kind, KINDS.index_by(&:itself), validate: true

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

  # Shown on the site: an approved waterfront result in a listed category.
  scope :published, -> { joins(:waterfront).merge(Verifications::Waterfront.listed) }

  # Best waterfront first, then the shortest measured distance. Unmeasured
  # properties come last.
  scope :by_waterfront, -> {
    left_joins(:waterfront).order(
      Arel.sql(sanitize_sql_array([ "array_position(ARRAY[?]::varchar[], verifications.category)", Verifications::Waterfront::CATEGORIES ])),
      Arel.sql("verifications.distance_m"), :name
    )
  }

  # Properties that an OTA labels beachfront although our measurement does not
  # support it.
  scope :beachfront_claim_conflicts, -> {
    joins(:waterfront)
      .where(id: Listing.where(claims_beachfront: true).select(:property_id))
      .where(verifications: { category: %w[not_waterfront walkable] })
  }

  scope :with_coordinate_mismatch, -> {
    where("properties.coord_mismatch_m > ?", Waterfront.config.fetch(:coordinate_mismatch_m))
  }

  def listed?
    waterfront&.listed? || false
  end

  # A person has approved or rejected one of its results, so imports must not
  # move it or overwrite what was entered.
  def reviewed?
    persisted? && verifications.where.not(qa_status: "pending").exists?
  end

  def lonlat=(value)
    super
    load_coordinates if lonlat
  end

  def coordinate_mismatch?
    coord_mismatch_m.to_i > Waterfront.config.fetch(:coordinate_mismatch_m)
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
