# Imports a destination's OSM data and records progress in an ImportRun.
class OsmImportJob < ApplicationJob
  RETRY_WAIT = 10.minutes
  ATTEMPTS = 3

  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  # Overpass rate-limits and times out under load (the client already retries
  # a few minutes); try the whole import again later.
  retry_on Osm::OverpassClient::Error, wait: RETRY_WAIT, attempts: ATTEMPTS do |job, error|
    job.import_run&.fail!("Gave up after #{ATTEMPTS} attempts: #{error.message}")
  end

  attr_reader :import_run

  # import_run_id is given when the admin starts the import; scheduled
  # refreshes create their own run.
  def perform(destination_id, import_run_id = nil)
    destination = Destination.find(destination_id)
    @import_run = import_run_id ? ImportRun.find(import_run_id) : destination.import_runs.create!(source: "osm")
    import_run.start!(attempt: executions)

    counts = Osm::DestinationImport.new(destination, progress: import_run.method(:progress!)).call
    import_run.succeed!(counts)
  rescue Osm::OverpassClient::Error => e
    import_run&.retrying!(e.message, retry_at: RETRY_WAIT.from_now) if executions < ATTEMPTS
    raise
  rescue ActiveRecord::RecordNotFound
    raise
  rescue StandardError => e
    import_run&.fail!("#{e.class}: #{e.message}")
    raise
  end
end
