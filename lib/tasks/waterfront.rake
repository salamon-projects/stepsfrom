namespace :waterfront do
  desc "Re-measure and classify every property of a destination (by slug), or all destinations"
  task :classify, [ :slug ] => :environment do |_, args|
    scope = args[:slug] ? Destination.where(slug: args[:slug]) : Destination.all
    scope.find_each do |destination|
      destination.properties.find_each { |property| Waterfront::Classification.new(property).call }
      counts = destination.properties.group(:waterfront_category).count
      puts "#{destination.name}: #{counts.sort.map { |category, n| "#{category}=#{n}" }.join(' ')}"
    end
  end
end
