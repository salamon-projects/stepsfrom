# Helpers for building geographic (SRID 4326) values.
module Geo
  SRID = 4326

  module_function

  def factory
    RGeo::Geographic.spherical_factory(srid: SRID)
  end

  def point(lon:, lat:)
    factory.point(lon.to_f, lat.to_f)
  end

  def line(coords)
    factory.line_string(coords.map { |lon, lat| factory.point(lon, lat) })
  end

  def polygon(coords)
    ring = coords.map { |lon, lat| factory.point(lon, lat) }
    ring << ring.first unless ring.first == ring.last
    factory.polygon(factory.linear_ring(ring))
  end

  # Rectangle from a south/west/north/east bounding box.
  def bbox_polygon(south:, west:, north:, east:)
    polygon([ [ west, south ], [ east, south ], [ east, north ], [ west, north ] ])
  end
end
