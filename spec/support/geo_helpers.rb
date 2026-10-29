# Builds geometries a given number of metres away from a reference point.
# Uses a local equirectangular approximation, accurate to well under a metre
# at the distances used in specs.
module GeoHelpers
  EARTH_RADIUS_M = 6_371_008.8

  BASE_LAT = 43.30
  BASE_LON = 17.02

  def offset(lat: BASE_LAT, lon: BASE_LON, north_m: 0, east_m: 0)
    dlat = north_m / EARTH_RADIUS_M * 180 / Math::PI
    dlon = east_m / (EARTH_RADIUS_M * Math.cos(lat * Math::PI / 180)) * 180 / Math::PI
    [ lon + dlon, lat + dlat ]
  end

  def point_at(north_m: 0, east_m: 0)
    lon, lat = offset(north_m:, east_m:)
    Geo.point(lon:, lat:)
  end

  # East-west line north_m metres north of the base point, `half_width_m`
  # metres either side.
  def east_west_line(north_m:, half_width_m: 500)
    Geo.line([ offset(north_m:, east_m: -half_width_m), offset(north_m:, east_m: half_width_m) ])
  end

  def box(south_m:, north_m:, west_m: -500, east_m: 500)
    Geo.polygon([
      offset(north_m: south_m, east_m: west_m), offset(north_m: south_m, east_m: east_m),
      offset(north_m: north_m, east_m: east_m), offset(north_m: north_m, east_m: west_m)
    ])
  end
end

RSpec.configure { |config| config.include GeoHelpers }
FactoryBot::SyntaxRunner.include GeoHelpers
