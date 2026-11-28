module Waterfront
  # Turns a Measurement into a waterfront category. Thresholds live in
  # config/waterfront.yml and are explained on the "How we verify" page.
  class Classifier
    def initialize(config = Waterfront.config)
      @config = config
    end

    def category_for(measurement)
      return "unknown" unless measurement.water_data_available

      distance = measurement.distance_to_water_m
      return "not_waterfront" if distance.nil? || distance > @config.fetch(:walkable_max_m)
      return beach_at_door?(measurement) ? "direct" : "seafront" if direct?(measurement)
      return "near" if distance <= @config.fetch(:near_max_m)

      "walkable"
    end

    private

    # Nothing but (at most) a beach between the property and the water.
    def direct?(measurement)
      return false if measurement.crosses_road

      distance = measurement.distance_to_water_m
      distance <= @config.fetch(:direct_max_m) || on_wide_beach?(measurement, distance)
    end

    # A beach between the property and the water, or one right next to it
    # that reaches the water where we measured. A harbour quay, a pier or
    # rocks with a beach further along are not "beachfront".
    def beach_at_door?(measurement)
      return true if measurement.crosses_beach

      measurement.beach_at_water_m.present? && measurement.beach_at_water_m <= @config.fetch(:beach_at_water_max_m)
    end

    def on_wide_beach?(measurement, distance)
      measurement.crosses_beach &&
        measurement.distance_to_beach_m.present? &&
        measurement.distance_to_beach_m <= @config.fetch(:beach_adjacent_m) &&
        distance <= @config.fetch(:direct_beach_max_m)
    end
  end
end
