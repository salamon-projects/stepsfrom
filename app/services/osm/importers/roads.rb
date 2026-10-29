module Osm
  module Importers
    # Roads and railways (which rule out direct waterfront) and promenades,
    # pedestrian streets and service roads (shown as information only).
    class Roads < Base
      ROAD = %w[motorway trunk primary secondary tertiary motorway_link trunk_link primary_link
                secondary_link tertiary_link unclassified residential living_street].freeze
      PROMENADE = %w[pedestrian service footway].freeze
      RAIL = %w[rail light_rail narrow_gauge tram].freeze
      IGNORED_SERVICE = %w[parking_aisle driveway drive-through].freeze

      private

      def model = RoadSegment

      def unique_by = %i[osm_id]

      def selectors
        [ %(way["highway"~"^(#{(ROAD + %w[pedestrian service]).join('|')})$"]),
          'way["highway"="footway"]["name"]',
          %(way["railway"~"^(#{RAIL.join('|')})$"]) ]
      end

      def row_for(element)
        line = element.line or return
        tags = element.tags
        return if tags["tunnel"].present? && tags["tunnel"] != "no"

        category = category_for(tags) or return
        { osm_id: element.id, category:, highway: tags["highway"] || tags["railway"], name: tags["name"], geom: line }
      end

      def category_for(tags)
        highway = tags["highway"]
        return "rail" if RAIL.include?(tags["railway"])
        return "road" if ROAD.include?(highway)
        return if highway == "service" && IGNORED_SERVICE.include?(tags["service"])

        "promenade" if PROMENADE.include?(highway)
      end
    end
  end
end
