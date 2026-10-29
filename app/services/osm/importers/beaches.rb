module Osm
  module Importers
    class Beaches < Base
      private

      def model = Beach

      def selectors
        [ 'way["natural"="beach"]', 'relation["natural"="beach"]' ]
      end

      def row_for(element)
        polygon = element.polygon or return

        { osm_type: element.type, osm_id: element.id, name: element.tags["name"],
          surface: Beach.normalize_surface(element.tags["surface"]), geom: polygon }
      end
    end
  end
end
