module Waterfront
  # Measures and classifies a property and stores the result. An approved
  # property goes back to review when its category changes or a booking site
  # starts reporting a clearly different position.
  class Classification
    def initialize(property, measurer: Measurer.new, classifier: Classifier.new)
      @property = property
      @measurer = measurer
      @classifier = classifier
    end

    def call
      measurement = @measurer.measure(@property)
      category = @classifier.category_for(measurement)

      attributes = measured_attributes(measurement).merge(
        waterfront_category: category, classified_at: Time.current, updated_at: Time.current
      )
      attributes.merge!(review_reset(category, measurement)) if @property.qa_approved?
      @property.update_columns(attributes)
      @property
    end

    private

    def measured_attributes(measurement)
      {
        water_feature_id: measurement.water_feature_id,
        water_kind: measurement.water_kind,
        water_name: measurement.water_name,
        water_point: measurement.water_point,
        distance_to_water_m: measurement.distance_to_water_m,
        distance_to_beach_m: measurement.distance_to_beach_m,
        beach_surface: measurement.beach_surface,
        crosses_road: measurement.crosses_road,
        crosses_promenade: measurement.crosses_promenade,
        coord_mismatch_m: measurement.coord_mismatch_m
      }
    end

    def review_reset(category, measurement)
      threshold = Waterfront.config.fetch(:coordinate_mismatch_m)
      reasons = []
      reasons << "category changed from #{@property.waterfront_category} to #{category}" if category != @property.waterfront_category
      if measurement.coord_mismatch_m.to_i > threshold && @property.coord_mismatch_m.to_i <= threshold
        reasons << "a booking site reports a position #{measurement.coord_mismatch_m} m away"
      end
      return {} if reasons.empty?

      { qa_status: "pending", qa_note: [ @property.qa_note.presence, "Back to review: #{reasons.join('; ')}." ].compact.join("\n") }
    end
  end
end
