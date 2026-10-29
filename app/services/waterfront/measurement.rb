module Waterfront
  # What Waterfront::Measurer found for one property.
  Measurement = Data.define(
    :water_data_available, # false when no water has been imported around the destination yet
    :water_feature_id, :water_kind, :water_name,
    :distance_to_water_m,
    :property_point,       # point on the property (footprint edge) closest to the water
    :water_point,          # closest point of the water
    :crosses_road,         # road or railway on the straight line to the water
    :crosses_promenade,    # promenade, pedestrian street or service road on it
    :crosses_beach,        # the line passes over a mapped beach
    :distance_to_beach_m, :beach_surface,
    :coord_mismatch_m      # largest distance to a booking site's reported position
  )
end
