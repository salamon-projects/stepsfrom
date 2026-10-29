module Osm
  # Imports every OSM layer for a destination, then reclassifies its
  # properties against the fresh geometry.
  class DestinationImport
    LAYERS = {
      coastline: Importers::Coastline,
      inland_water: Importers::InlandWater,
      beaches: Importers::Beaches,
      roads: Importers::Roads,
      accommodations: Importers::Accommodations
    }.freeze

    def initialize(destination, client: OverpassClient.new)
      @destination = destination
      @client = client
    end

    # Returns the number of imported features per layer.
    def call
      counts = LAYERS.transform_values { |importer| importer.new(@destination, client: @client).call }
      @destination.properties.find_each { |property| Waterfront::Classification.new(property).call }
      counts
    end
  end
end
