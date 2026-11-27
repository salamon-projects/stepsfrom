module GuidesHelper
  # One factual line about a ranked stay, from its measurement only: how far
  # the water is, whether a road or railway is in between, and the nearest
  # mapped beach.
  def guide_fact(property)
    waterfront = property.waterfront
    return if waterfront&.distance_m.nil?

    name = property.name
    water = waterfront.water_display_name
    position = if waterfront.distance_m.zero?
      t("guides.fact.on_the_water", name:, water:)
    else
      t("guides.fact.distance", name:, distance: number_with_delimiter(waterfront.distance_m), water:)
    end
    between = t(waterfront.crosses_road? ? "guides.fact.road" : "guides.fact.no_road")
    [ "#{position}, #{between}.", guide_beach_fact(waterfront) ].compact.join(" ")
  end

  private

  def guide_beach_fact(waterfront)
    distance = waterfront.distance_to_beach_m
    return if distance.nil?

    surface = t("waterfront.beach_surfaces.#{waterfront.beach_surface}", default: nil) if waterfront.beach_surface.present?
    where = distance.to_i.zero? ? t("guides.fact.beach_touching") : t("guides.fact.beach_metres", distance:)
    t("guides.fact.beach", where: [ where, surface&.downcase ].compact.join(", "))
  end
end
