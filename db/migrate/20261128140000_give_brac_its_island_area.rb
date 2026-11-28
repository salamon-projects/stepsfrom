# Brač's rectangle also covered the mainland Omiš Riviera (Ruskamen, Mimice,
# Nemira, Duće, Pisak), so dozens of mainland stays were listed under Brač.
# Its area becomes the island polygon from config/destination_areas.yml;
# properties outside it stay in the database (and admin) but are no longer
# listed.
class GiveBracItsIslandArea < ActiveRecord::Migration[8.1]
  RECTANGLE = { south: 43.25, west: 16.38, north: 43.42, east: 16.90 }.freeze

  def up
    ring = Rails.application.config_for(:destination_areas).fetch(:brac)
    set_area("POLYGON((#{ring.map { |lon, lat| "#{lon} #{lat}" }.join(', ')}))")
  end

  def down
    south, west, north, east = RECTANGLE.values_at(:south, :west, :north, :east)
    set_area("POLYGON((#{west} #{south}, #{east} #{south}, #{east} #{north}, #{west} #{north}, #{west} #{south}))")
  end

  private

  def set_area(wkt)
    execute <<~SQL
      UPDATE destinations
      SET area = ST_GeogFromText(#{quote(wkt)}),
          center = ST_Centroid(ST_Envelope(ST_GeomFromText(#{quote(wkt)}, 4326)))::geography,
          updated_at = now()
      WHERE slug = 'brac'
    SQL
  end
end
