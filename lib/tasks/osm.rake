namespace :osm do
  desc "Import OSM water, beaches, roads and accommodation for a destination (by slug)"
  task :import, [ :slug ] => :environment do |_, args|
    destination = Destination.find_by!(slug: args.fetch(:slug))
    counts = Osm::DestinationImport.new(destination).call
    puts "#{destination.name}: #{counts.map { |layer, n| "#{layer}=#{n}" }.join(' ')}"
  end

  desc "Import OSM data for every destination"
  task import_all: :environment do
    Destination.ordered.each do |destination|
      counts = Osm::DestinationImport.new(destination).call
      puts "#{destination.name}: #{counts.map { |layer, n| "#{layer}=#{n}" }.join(' ')}"
    end
  end
end
