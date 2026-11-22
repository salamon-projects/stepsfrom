namespace :affiliate do
  desc "Create or update automatic booking-site listings now (for a destination slug, or all)"
  task :auto_listings, [ :slug ] => :environment do |_, args|
    destination_id = Destination.find_by!(slug: args[:slug]).id if args[:slug].present?
    counts = AutoListingsJob.perform_now(destination_id)
    puts counts.map { |result, count| "#{count} #{result}" }.join(", ")
  end
end
