module Osm
  module Importers
    # Named tourism=* accommodation. New properties start pending review.
    # Reviewed (approved or rejected) properties keep their geometry, so a
    # re-import never overrides a manual coordinate correction.
    class Accommodations < Base
      KINDS = { "hotel" => "hotel", "motel" => "motel", "guest_house" => "guest_house", "hostel" => "hostel",
                "apartment" => "apartment", "chalet" => "chalet", "camp_site" => "camp_site" }.freeze

      def call
        count = 0
        client.query(query).each do |element|
          count += 1 if import_element(element)
        end
        count
      end

      private

      def selectors
        %w[node way relation].map { |type| %(#{type}["tourism"~"^(#{KINDS.keys.join('|')})$"]["name"]) }
      end

      def import_element(element)
        point = element.point or return false
        name = element.tags["name"].presence or return false

        property = Property.find_or_initialize_by(osm_type: element.type, osm_id: element.id)
        if property.new_record?
          property.assign_attributes(destination:, name:, kind: KINDS.fetch(element.tags["tourism"], "hotel"))
        end
        property.assign_attributes(details(element.tags))
        property.assign_attributes(lonlat: point, footprint: element.polygon) if property.new_record? || property.qa_pending?
        property.save!
        true
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn("Skipping OSM #{element.type}/#{element.id}: #{e.message}")
        false
      end

      def details(tags)
        stars = tags["stars"].to_s[/\A[1-5]/]&.to_i
        website = [ tags["website"], tags["contact:website"] ].compact.map(&:strip).find { |url| url.match?(Property::WEBSITE_FORMAT) }
        street = [ tags["addr:street"], tags["addr:housenumber"] ].compact.join(" ").presence
        address = [ street, tags["addr:city"] || tags["addr:place"] ].compact.join(", ").presence

        { stars:, website:, address: }.compact
      end
    end
  end
end
