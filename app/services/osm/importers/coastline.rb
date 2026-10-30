module Osm
  module Importers
    # Sea coastline ways. The sea is on the right-hand side of each way.
    class Coastline < Base
      private

      def model = WaterFeature

      def layer_scope = model.where(kind: "sea")

      def selectors
        [ 'way["natural"="coastline"]' ]
      end

      def row_for(element)
        line = element.line or return

        { osm_type: element.type, osm_id: element.id, kind: "sea", name: nil, geom: line }
      end
    end
  end
end
