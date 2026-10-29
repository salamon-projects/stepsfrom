module PropertiesHelper
  def waterfront_badge(property, large: false)
    tag.span(t("waterfront.categories.#{property.waterfront_category}"),
             class: [ "badge", "badge--#{property.waterfront_category}", ("badge--large" if large) ],
             title: waterfront_hint(property))
  end

  def waterfront_hint(property)
    config = Waterfront.config
    t("waterfront.category_hints.#{property.waterfront_category}",
      near: config.fetch(:near_max_m), walkable: config.fetch(:walkable_max_m), default: nil)
  end

  def measured_distance(property)
    return if property.distance_to_water_m.nil?

    if property.distance_to_water_m.zero?
      t("waterfront.on_the_water", water: property.water_display_name)
    else
      t("waterfront.measured", distance: number_with_delimiter(property.distance_to_water_m), water: property.water_display_name)
    end
  end

  def property_kind(property)
    label = t("properties.kinds.#{property.kind}")
    property.stars ? "#{label} · #{'★' * property.stars}" : label
  end

  def beach_surface_label(property)
    t("waterfront.beach_surfaces.#{property.beach_surface}") if property.beach_surface.present?
  end

  # Notes shown under the badge: what lies between the property and the water.
  def waterfront_notes(property)
    notes = []
    notes << [ :warning, t("waterfront.road_between") ] if property.crosses_road?
    notes << [ :info, t("waterfront.promenade_between") ] if property.crosses_promenade?
    notes << [ :info, beach_surface_label(property) ] if property.beach_surface.present?
    notes
  end

  def property_map_data(property)
    data = { properties: [ map_point(property) ], maxZoom: 18 }
    data[:footprint] = property.footprint.exterior_ring.points.map { |p| [ p.y, p.x ] } if property.footprint
    if property.water_point
      from = property.footprint ? closest_point_on_footprint(property) : property.lonlat
      data[:measurement] = {
        from: [ from.y, from.x ], to: [ property.water_point.y, property.water_point.x ],
        label: t("waterfront.measured_short", distance: property.distance_to_water_m)
      }
    end
    data
  end

  def destination_map_data(destination, points)
    { center: [ destination.center.y, destination.center.x ], zoom: destination.zoom, maxZoom: 16, properties: points }
  end

  def map_point(property, url: nil)
    { lat: property.lonlat.y, lon: property.lonlat.x, name: property.name, category: property.waterfront_category, url: }
  end

  private

  # The footprint vertex nearest the water point; close enough to draw the
  # measurement line from the building edge.
  def closest_point_on_footprint(property)
    water = property.water_point
    property.footprint.exterior_ring.points.min_by { |p| (p.x - water.x)**2 + (p.y - water.y)**2 }
  end
end
