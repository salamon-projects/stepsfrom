module Waterfront
  # Measures a property against the imported OSM layers in PostGIS. Distances
  # are geodesic metres; the property is measured from its footprint when it
  # has one, so a large building is not penalised for its centroid.
  class Measurer
    # Ignore this much at each end of the line to the water, so a road that
    # merely touches the building or the shoreline does not count as crossed.
    LINE_END_TOLERANCE_M = 2.0

    def initialize(config = Waterfront.config)
      @config = config
    end

    def measure(property)
      water = nearest_water(property)
      beach = nearest_beach(property)
      line = water && measurement_line(water)
      crossings = line ? crossings(line) : []

      Measurement.new(
        water_data_available: water.present? || water_data_available?(property),
        water_feature_id: water&.fetch("id"),
        water_kind: water&.fetch("kind"),
        water_name: water&.fetch("name"),
        distance_to_water_m: water && water.fetch("distance").round,
        property_point: water && parse_point(water.fetch("property_point")),
        water_point: water && parse_point(water.fetch("water_point")),
        crosses_road: crossings.intersect?(%w[road rail]),
        crosses_promenade: crossings.include?("promenade"),
        crosses_beach: line ? crosses_beach?(line) : false,
        distance_to_beach_m: beach && beach.fetch("distance").round,
        beach_surface: beach&.fetch("surface"),
        coord_mismatch_m: coordinate_mismatch(property)
      )
    end

    private

    def select_one(sql, *binds)
      ActiveRecord::Base.connection.select_one(ActiveRecord::Base.sanitize_sql_array([ sql, *binds ]))
    end

    def select_values(sql, *binds)
      ActiveRecord::Base.connection.select_values(ActiveRecord::Base.sanitize_sql_array([ sql, *binds ]))
    end

    def source_sql
      "(SELECT COALESCE(footprint, lonlat) AS g FROM properties WHERE id = ?)"
    end

    def nearest_water(property)
      select_one(<<~SQL, property.id, @config.fetch(:search_radius_m))
        SELECT w.id, w.kind, w.name, ST_Distance(src.g, w.geom) AS distance,
               ST_AsText(ST_ClosestPoint(src.g::geometry, w.geom::geometry)) AS property_point,
               ST_AsText(ST_ClosestPoint(w.geom::geometry, src.g::geometry)) AS water_point
        FROM water_features w, #{source_sql} src
        WHERE ST_DWithin(src.g, w.geom, ?)
        ORDER BY ST_Distance(src.g, w.geom), w.id
        LIMIT 1
      SQL
    end

    def nearest_beach(property)
      select_one(<<~SQL, property.id, @config.fetch(:walkable_max_m))
        SELECT b.surface, ST_Distance(src.g, b.geom) AS distance
        FROM beaches b, #{source_sql} src
        WHERE ST_DWithin(src.g, b.geom, ?)
        ORDER BY ST_Distance(src.g, b.geom), b.id
        LIMIT 1
      SQL
    end

    def water_data_available?(property)
      select_values(<<~SQL, property.destination_id).any?
        SELECT 1 FROM water_features w, destinations d
        WHERE d.id = ? AND ST_Intersects(w.geom, d.area)
        LIMIT 1
      SQL
    end

    # The straight line from the property to the water as WKT, trimmed at
    # both ends; nil when it is too short for anything to lie between.
    def measurement_line(water)
      distance = water.fetch("distance")
      return if distance <= LINE_END_TOLERANCE_M * 2

      fraction = LINE_END_TOLERANCE_M / distance
      select_values(<<~SQL, water.fetch("property_point"), water.fetch("water_point"), fraction, 1 - fraction).first
        SELECT ST_AsText(ST_LineSubstring(ST_MakeLine(ST_GeomFromText(?, 4326), ST_GeomFromText(?, 4326)), ?, ?))
      SQL
    end

    def crossings(line)
      select_values(<<~SQL, line)
        SELECT DISTINCT r.category FROM road_segments r
        WHERE ST_Intersects(r.geom, ST_GeogFromText(?))
      SQL
    end

    def crosses_beach?(line)
      select_values(<<~SQL, line).any?
        SELECT 1 FROM beaches b WHERE ST_Intersects(b.geom, ST_GeogFromText(?)) LIMIT 1
      SQL
    end

    def coordinate_mismatch(property)
      distance = select_values(<<~SQL, property.id).first
        SELECT MAX(ST_Distance(p.lonlat, l.reported_lonlat)) FROM listings l
        JOIN properties p ON p.id = l.property_id
        WHERE l.property_id = ? AND l.active AND l.reported_lonlat IS NOT NULL
      SQL
      distance&.round
    end

    def parse_point(wkt)
      Geo.factory.parse_wkt(wkt)
    end
  end
end
