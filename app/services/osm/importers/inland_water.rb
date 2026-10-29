module Osm
  module Importers
    # Lakes, reservoirs and river areas mapped as natural=water polygons.
    # Multipolygon relations are limited to their first closed outer ring.
    class InlandWater < Base
      KINDS = { "lake" => "lake", "reservoir" => "lake", "lagoon" => "lake", "river" => "river" }.freeze

      private

      def model = WaterFeature

      def selectors
        [ 'way["natural"="water"]["water"~"^(lake|reservoir|lagoon|river)$"]',
          'relation["natural"="water"]["water"~"^(lake|reservoir|lagoon|river)$"]' ]
      end

      def row_for(element)
        polygon = element.polygon or return
        kind = KINDS[element.tags["water"]] or return

        { osm_type: element.type, osm_id: element.id, kind:, name: element.tags["name"], geom: polygon }
      end
    end
  end
end
