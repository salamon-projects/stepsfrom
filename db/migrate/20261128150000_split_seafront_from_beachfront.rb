# "Verified beachfront" counted any shore within 50 m with no road in
# between, so a hotel on a harbour quay or on rocks was beachfront too. Now
# it needs a beach at the door; the rest are "seafront". Only properties
# measured as direct can change, so only those are measured again.
class SplitSeafrontFromBeachfront < ActiveRecord::Migration[8.1]
  def up
    property_ids = select_values(<<~SQL)
      SELECT property_id FROM verifications
      WHERE type = 'Verifications::Waterfront' AND category = 'direct'
    SQL

    Property.where(id: property_ids).find_each { |property| Waterfront::Classification.new(property).call }
  end

  def down
    execute <<~SQL
      UPDATE verifications SET category = 'direct'
      WHERE type = 'Verifications::Waterfront' AND category = 'seafront'
    SQL
  end
end
