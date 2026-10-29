module Osm
  module Importers
    # Imports one OSM layer for a destination's bounding box.
    class Base
      attr_reader :destination, :client

      def initialize(destination, client: OverpassClient.new)
        @destination = destination
        @client = client
      end

      # Returns the number of imported features.
      def call
        rows = client.query(query).filter_map { |element| row_for(element) }
        import(rows)
        rows.size
      end

      private

      def query
        "[out:json][timeout:300];(#{selectors.map { |s| "#{s}#{bbox_filter};" }.join});out geom;"
      end

      def bbox_filter
        "(#{destination.bbox.join(',')})"
      end

      def import(rows)
        rows.uniq { |row| row.values_at(*unique_by) }.each_slice(500) do |batch|
          model.upsert_all(batch, unique_by:)
        end
      end

      def unique_by
        %i[osm_type osm_id]
      end
    end
  end
end
