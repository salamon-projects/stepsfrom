module Waterfront
  # Measures and classifies a property and stores the result as its
  # Verifications::Waterfront. An approved result goes back to review when its
  # category changes or a booking site starts reporting a clearly different
  # position.
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

      reasons = review_reasons(verification, category, measurement) if verification.qa_approved?
      verification.assign_attributes(
        category:, distance_m: measurement.distance_to_water_m, evidence: evidence(measurement), measured_at: Time.current
      )
      if reasons.present?
        verification.qa_status = "pending"
        verification.qa_note = [ verification.qa_note.presence, "Back to review: #{reasons.join('; ')}." ].compact.join("\n")
      end
      verification.save!

      @property.update_columns(coord_mismatch_m: measurement.coord_mismatch_m, updated_at: Time.current)
      @property
    end

    private

    def evidence(measurement)
      point = measurement.water_point
      {
        water_feature_id: measurement.water_feature_id,
        water_kind: measurement.water_kind,
        water_name: measurement.water_name,
        water_point: point && [ point.x, point.y ],
        distance_to_beach_m: measurement.distance_to_beach_m,
        beach_surface: measurement.beach_surface,
        crosses_road: measurement.crosses_road,
        crosses_promenade: measurement.crosses_promenade
      }
    end

    def review_reasons(verification, category, measurement)
      threshold = Waterfront.config.fetch(:coordinate_mismatch_m)
      reasons = []
      reasons << "category changed from #{verification.category} to #{category}" if category != verification.category
      if measurement.coord_mismatch_m.to_i > threshold && @property.coord_mismatch_m.to_i <= threshold
        reasons << "a booking site reports a position #{measurement.coord_mismatch_m} m away"
      end
      reasons
    end
  end
end
