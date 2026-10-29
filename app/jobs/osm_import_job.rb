class OsmImportJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(destination_id)
    destination = Destination.find(destination_id)
    counts = Osm::DestinationImport.new(destination).call
    Rails.logger.info("OSM import for #{destination.slug}: #{counts.inspect}")
  end
end
