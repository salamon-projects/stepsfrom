class OsmImportJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound
  # Overpass rate-limits and times out under load; try again later.
  retry_on Osm::OverpassClient::Error, wait: 10.minutes, attempts: 3

  def perform(destination_id)
    destination = Destination.find(destination_id)
    counts = Osm::DestinationImport.new(destination).call
    Rails.logger.info("OSM import for #{destination.slug}: #{counts.inspect}")
  end
end
