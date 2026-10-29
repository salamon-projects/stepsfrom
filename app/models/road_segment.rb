# A road, railway or promenade way imported from OpenStreetMap. Roads and
# railways between a property and the water rule out "direct" waterfront;
# promenades are shown as information only.
class RoadSegment < ApplicationRecord
  CATEGORIES = %w[road rail promenade].freeze

  enum :category, CATEGORIES.index_by(&:itself), validate: true

  validates :osm_id, :geom, presence: true
end
