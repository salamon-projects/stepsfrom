# natural=beach area imported from OpenStreetMap.
class Beach < ApplicationRecord
  validates :osm_type, :osm_id, :geom, presence: true

  # Normalises the OSM surface tag to the few values shown to visitors.
  def self.normalize_surface(value)
    case value.to_s
    when "sand", "fine_sand" then "sand"
    when "pebblestone", "gravel", "pebbles", "shingle", "fine_gravel" then "pebble"
    when "rock", "stone", "concrete", "paved" then "rock"
    end
  end
end
