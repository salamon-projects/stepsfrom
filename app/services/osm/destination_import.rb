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

    # Returns the number of imported features per layer, and how many
    # properties could not be measured.
    def call
      counts = LAYERS.transform_values { |importer| importer.new(@destination, client: @client).call }
      counts.merge(measurement_failures: classify_properties)
    end

    private

    # A broken OSM geometry must not stop the other properties from being
    # measured; failures are logged and the property keeps its old result.
    def classify_properties
      failures = 0
      @destination.properties.find_each do |property|
        Waterfront::Classification.new(property).call
      rescue ActiveRecord::StatementInvalid => e
        failures += 1
        Rails.logger.error("Could not measure property #{property.id} (#{property.slug}): #{e.message}")
      end
      failures
    end
  end
end
