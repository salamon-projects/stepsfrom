class Destination < ApplicationRecord
  include Sluggable

  # Verifications, listings and quotes go with the properties (database
  # cascades); logged outbound clicks keep their row without the property.
  has_many :properties, dependent: :delete_all
  has_many :import_runs, dependent: :delete_all

  normalizes :country_code, with: ->(code) { code.strip.upcase }

  attribute :south, :float
  attribute :west, :float
  attribute :north, :float
  attribute :east, :float

  validates :name, :country_code, presence: true
  validates :country_code, format: { with: /\A[A-Z]{2}\z/ }
  validates :zoom, numericality: { only_integer: true, in: 3..18 }
  validates :area, :center, presence: true
  validate :bbox_is_ordered

  # The four numbers only rebuild the area when they were changed, so saving
  # a destination with a non-rectangular area (config/destination_areas.yml)
  # keeps it. Changing them in the admin replaces it with that rectangle.
  before_validation :build_area_from_bbox, if: -> { bbox_given? && bbox_changed? }
  before_validation :center_on_area, if: -> { area.present? && will_save_change_to_area? }

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :name) }

  after_initialize :load_bbox_from_area, if: -> { has_attribute?(:area) && area.present? && !bbox_given? }

  # SQL condition for "the point lies in its destination's area", for a
  # query where `destinations` is that destination. Compared in plain lon/lat
  # like the bounding boxes Overpass is queried with, so a property imported
  # from a rectangular destination's box is inside its area.
  COVERS_SQL = "ST_Covers(destinations.area::geometry, %s::geometry)".freeze

  def self.covers_sql(point_column)
    format(COVERS_SQL, point_column)
  end

  # The configured non-rectangular area for a slug (config/destination_areas.yml),
  # or nil.
  def self.configured_area(slug)
    ring = Rails.application.config_for(:destination_areas)[slug.to_sym] or return
    Geo.polygon(ring)
  end

  # [south, west, north, east], the order Overpass expects.
  def bbox
    [ south, west, north, east ]
  end

  # Whether the point lies in the area (see COVERS_SQL).
  def covers?(point)
    return false unless persisted? && point

    self.class.where(id:).where(self.class.covers_sql("ST_GeomFromText(:wkt, 4326)"), wkt: point.as_text).exists?
  end

  # False for an area of another shape (config/destination_areas.yml), which
  # the four bounding box numbers only describe as its envelope.
  def rectangular?
    area.blank? || area.exterior_ring.num_points == 5 && area == Geo.bbox_polygon(south:, west:, north:, east:)
  end

  def country_name
    I18n.t("countries.#{country_code}", default: country_code)
  end

  private

  def bbox_given?
    [ south, west, north, east ].all?(&:present?)
  end

  def bbox_changed?
    %w[south west north east].any? { |attribute| attribute_changed?(attribute) }
  end

  def bbox_is_ordered
    return unless bbox_given?

    errors.add(:north, :greater_than, count: :south) unless north > south
    errors.add(:east, :greater_than, count: :west) unless east > west
  end

  def build_area_from_bbox
    return unless north > south && east > west

    self.area = Geo.bbox_polygon(south:, west:, north:, east:)
  end

  # Centered on the area's bounding box, whose numbers are kept in step.
  def center_on_area
    load_bbox_from_area
    self.center = Geo.point(lon: (west + east) / 2.0, lat: (south + north) / 2.0)
  end

  def load_bbox_from_area
    lons = area.exterior_ring.points.map(&:x)
    lats = area.exterior_ring.points.map(&:y)
    self.south, self.north = lats.minmax
    self.west, self.east = lons.minmax
    clear_attribute_changes(%i[south west north east])
  end
end
