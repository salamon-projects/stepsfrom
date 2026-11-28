# Kassandra's rectangle also covered the west coast of Sithonia, so Porto
# Carras, Elia, Vourvourou and others were listed under Kassandra. Its area
# becomes the peninsula polygon from config/destination_areas.yml; properties
# outside it stay in the database (and admin) but are no longer listed.
class GiveKassandraItsPeninsulaArea < ActiveRecord::Migration[8.1]
  RECTANGLE = { south: 39.90, west: 23.30, north: 40.25, east: 23.80 }.freeze

  def up
    ring = Rails.application.config_for(:destination_areas).fetch(:kassandra)
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
      WHERE slug = 'kassandra'
    SQL
  end
end
