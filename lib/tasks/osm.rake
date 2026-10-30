namespace :osm do
  # Runs the import inline, recording it as an ImportRun like the admin does.
  def run_osm_import(destination)
    run = destination.import_runs.create!(source: "osm")
    run.start!(attempt: 1)
    counts = Osm::DestinationImport.new(destination, progress: run.method(:progress!)).call
    run.succeed!(counts)
    puts "#{destination.name}: #{counts.map { |layer, n| "#{layer}=#{n}" }.join(' ')}"
  rescue StandardError => e
    run&.fail!("#{e.class}: #{e.message}")
    raise
  end

  desc "Import OSM water, beaches, roads and accommodation for a destination (by slug)"
  task :import, [ :slug ] => :environment do |_, args|
    run_osm_import(Destination.find_by!(slug: args.fetch(:slug)))
  end

  desc "Import OSM data for every destination"
  task import_all: :environment do
    Destination.ordered.each { |destination| run_osm_import(destination) }
  end
end
