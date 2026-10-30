module Verifications
  # Whether the property is on the water, measured by Waterfront::Classification
  # against OpenStreetMap data. distance_m is the distance to the water.
  class Waterfront < Verification
    CATEGORIES = %w[direct near walkable not_waterfront unknown].freeze
    LISTED_CATEGORIES = %w[direct near walkable].freeze

    enum :category, CATEGORIES.index_by(&:itself), validate: true

    store_accessor :evidence, :water_feature_id, :water_kind, :water_name, :water_point,
                   :distance_to_beach_m, :beach_surface, :crosses_road, :crosses_promenade

    alias_attribute :distance_to_water_m, :distance_m

    def crosses_road?
      crosses_road == true
    end

    def crosses_promenade?
      crosses_promenade == true
    end

    # "the Adriatic Sea", "Lake Bled", or a generic "the sea".
    def water_display_name
      return water_name if water_name.present?

      sea_name = property.destination.sea_name
      return "the #{sea_name}" if sea_name.present? && (water_kind.nil? || water_kind == "sea")

      I18n.t("properties.water_kinds.#{water_kind || 'sea'}")
    end
  end
end
