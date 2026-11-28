module Waterfront
  # Measures and classifies a property and stores the result as its
  # Verifications::Waterfront.
  class Classification
    def initialize(property, measurer: Measurer.new, classifier: Classifier.new)
      @property = property
      @measurer = measurer
      @classifier = classifier
    end

    def call
      measurement = @measurer.measure(@property)
      category = @classifier.category_for(measurement)
      verification = @property.waterfront || @property.build_waterfront
      verification.assign_attributes(category:, distance_m: measurement.distance_to_water_m, evidence: evidence(measurement))
      save(verification)

      # updated_at moves only when something changed, so the sitemap's
      # lastmod reflects real changes rather than the weekly re-measuring.
      if @property.coord_mismatch_m != measurement.coord_mismatch_m
        @property.update_columns(coord_mismatch_m: measurement.coord_mismatch_m, updated_at: Time.current)
      end
      @property
    end

    private

    # A changed result is saved (and touched); an unchanged one only records
    # when it was measured.
    def save(verification)
      if verification.new_record? || verification.changed?
        verification.update!(measured_at: Time.current)
      else
        verification.update_columns(measured_at: Time.current)
      end
    end

    def evidence(measurement)
      point = measurement.water_point
      {
        water_feature_id: measurement.water_feature_id,
        water_kind: measurement.water_kind,
        water_name: measurement.water_name,
        water_point: point && [ point.x, point.y ],
        distance_to_beach_m: measurement.distance_to_beach_m,
        beach_surface: measurement.beach_surface,
        beach_at_water_m: measurement.beach_at_water_m,
        crosses_road: measurement.crosses_road,
        crosses_promenade: measurement.crosses_promenade
      }
    end
  end
end
