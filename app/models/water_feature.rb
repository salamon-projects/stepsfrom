# Sea coastline or inland water geometry imported from OpenStreetMap.
class WaterFeature < ApplicationRecord
  KINDS = %w[sea lake river].freeze

  enum :kind, KINDS.index_by(&:itself), validate: true

  has_many :properties, dependent: :nullify

  validates :osm_type, :osm_id, :geom, presence: true
end
