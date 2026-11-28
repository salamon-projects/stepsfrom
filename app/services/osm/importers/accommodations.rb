module Osm
  module Importers
    # Named tourism=* accommodation. Overpass is queried by the destination's
    # bounding box, but a new property is only added when it lies in the
    # destination's area, which need not be a rectangle (Kassandra's box also
    # covers part of Sithonia). Properties an admin edited or hid keep
    # their name, geometry and any details already set, so a re-import never
    # overrides a manual correction. Properties are never deleted: one that
    # OSM no longer returns is flagged (osm_missing_since) and leaves the site.
    #
    # Also kept: all OSM tags, the last edit's time and version; a tag showing
    # the place is mainly something else (non_lodging_tag, e.g. a dive centre
    # with a few rooms), which keeps it off the site until an admin approves
    # it; and which property it repeats when the same place is mapped twice
    # (duplicate_of_id), which keeps the repeat off the site.
    class Accommodations < Base
      KINDS = { "hotel" => "hotel", "motel" => "motel", "guest_house" => "guest_house", "hostel" => "hostel",
                "apartment" => "apartment", "chalet" => "chalet", "camp_site" => "camp_site" }.freeze

      # Keys whose any value says the place is mainly something else.
      NON_LODGING_KEYS = %w[shop office craft].freeze
      # amenity=* values a hotel may also carry (its restaurant or bar).
      LODGING_AMENITIES = %w[restaurant bar cafe pub fast_food biergarten ice_cream nightclub spa].freeze
      NON_LODGING_VALUES = { "sport" => %w[scuba_diving diving free_diving],
                             "leisure" => %w[sports_centre marina water_park] }.freeze

      # The same name this close is the same place mapped twice (often a node
      # and the building's outline). Names are compared without these words,
      # so "Hotel Dalmacija" and "Dalmacija" match.
      DUPLICATE_DISTANCE_M = 60
      GENERIC_NAME_WORDS = %w[hotel hotels hostel apartment apartments apartmani apartmaji villa vila guesthouse guest house
                              rooms sobe pension pansion studios studio suites resort].freeze

      def call
        @seen_ids = Set.new
        elements = client.query(query)
        count = elements.count { |element| import_element(element) }
        if elements.any?
          flag_missing
          flag_duplicates
        end
        count
      end

      private

      # With each element's last edit (time and version) as well.
      def query
        super.sub(/out geom;\z/, "out geom meta;")
      end

      # Flags this destination's OSM properties inside the box (what Overpass
      # was asked for, so also any outside the area) that the query did not
      # return (deleted from OSM, or no longer a named accommodation), and
      # clears the flag on those that are back.
      def flag_missing
        Property.where(id: @seen_ids.to_a).where.not(osm_missing_since: nil).update_all(osm_missing_since: nil)
        destination.properties.where.not(osm_id: nil).where(osm_missing_since: nil).where.not(id: @seen_ids.to_a)
                   .where(*inside_bbox("properties.lonlat")).update_all(osm_missing_since: Time.current)
      end

      # Marks each property that repeats another of the destination (the same
      # name, letters and digits only and without GENERIC_NAME_WORDS, within
      # DUPLICATE_DISTANCE_M). The one
      # with a building outline, else the older one, is kept. A property an
      # admin edited is never marked, so clearing a mark by editing sticks.
      # Written without touching updated_at, like the missing flag.
      def flag_duplicates
        destination.properties.where(reviewed_at: nil).where.not(duplicate_of_id: nil).update_all(duplicate_of_id: nil)
        generic = "\\m(#{GENERIC_NAME_WORDS.join('|')})\\M"
        sql = ActiveRecord::Base.sanitize_sql_array([ <<~SQL, generic, destination.id, DUPLICATE_DISTANCE_M ])
          WITH candidates AS (
            SELECT id, lonlat, footprint IS NOT NULL AS outlined, reviewed_at,
                   regexp_replace(regexp_replace(lower(name), ?, '', 'g'), '[^[:alnum:]]+', '', 'g') AS name_key
            FROM properties
            WHERE destination_id = ? AND osm_missing_since IS NULL AND duplicate_of_id IS NULL
          ),
          repeats AS (
            SELECT DISTINCT ON (repeat.id) repeat.id, kept.id AS kept_id
            FROM candidates repeat
            JOIN candidates kept ON kept.name_key = repeat.name_key AND kept.id <> repeat.id
              AND ST_DWithin(kept.lonlat, repeat.lonlat, ?)
              AND (kept.outlined, -kept.id) > (repeat.outlined, -repeat.id)
            WHERE repeat.reviewed_at IS NULL AND repeat.name_key <> ''
            ORDER BY repeat.id, kept.outlined DESC, kept.id
          )
          UPDATE properties SET duplicate_of_id = repeats.kept_id
          FROM repeats WHERE properties.id = repeats.id
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end

      def selectors
        %w[node way relation].map { |type| %(#{type}["tourism"~"^(#{KINDS.keys.join('|')})$"]["name"]) }
      end

      def import_element(element)
        point = element.point or return false
        name, local_name = display_name(element.tags)
        return false unless name

        property = Property.find_or_initialize_by(osm_type: element.type, osm_id: element.id)
        @seen_ids << property.id if property.persisted?
        return false if property.new_record? && !destination.covers?(point)

        if property.new_record?
          property.assign_attributes(destination:, kind: KINDS.fetch(element.tags["tourism"], "hotel"))
        end
        unreviewed = !property.reviewed?
        details = details(element.tags)
        details = details.select { |attribute, _| property.public_send(attribute).blank? } unless unreviewed
        property.assign_attributes(details)
        property.assign_attributes(name:, local_name:, lonlat: point, footprint: element.polygon) if unreviewed
        property.save!
        record_osm_details(property, element)
        @seen_ids << property.id
        true
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn("Skipping OSM #{element.type}/#{element.id}: #{e.message}")
        false
      end

      # [name, local_name]. The site is in English: a name in another script
      # gives way to its English or international form when OSM has one, or,
      # for Greek, to its transliteration; local_name keeps the original.
      def display_name(tags)
        name = tags["name"].to_s.strip.presence or return
        return [ name, nil ] if name.match?(/\A[\p{Latin}\p{Common}\p{Inherited}]*\z/)

        latin = [ tags["name:en"], tags["int_name"] ].map { |n| n.to_s.strip }.find(&:present?)
        latin ||= Transliteration.from_greek(name) if Transliteration.greek?(name)
        latin ? [ latin, name ] : [ name, nil ]
      end

      def details(tags)
        stars = tags["stars"].to_s[/\A[1-5]/]&.to_i
        website = [ tags["website"], tags["contact:website"] ].compact.map(&:strip).find { |url| url.match?(Property::WEBSITE_FORMAT) }
        street = [ tags["addr:street"], tags["addr:housenumber"] ].compact.join(" ").presence
        address = [ street, tags["addr:city"] || tags["addr:place"] ].compact.join(", ").presence

        { stars:, website:, address: }.compact
      end

      # OSM's own record of the place, written without touching updated_at
      # (the sitemap's lastmod): tags and versions change for reasons
      # visitors never see.
      def record_osm_details(property, element)
        values = { osm_tags: element.tags, osm_timestamp: element.timestamp, osm_version: element.version,
                   non_lodging_tag: non_lodging_tag(element.tags) }
        changed = values.reject { |attribute, value| property.public_send(attribute) == value }
        property.update_columns(changed) if changed.any?
      end

      # "amenity=dive_centre" when the tags say the place is mainly something
      # other than somewhere to stay.
      def non_lodging_tag(tags)
        key = NON_LODGING_KEYS.find { |k| tags[k].present? }
        return "#{key}=#{tags[key]}" if key

        amenity = tags["amenity"].presence
        return "amenity=#{amenity}" if amenity && LODGING_AMENITIES.exclude?(amenity)

        NON_LODGING_VALUES.each { |k, values| return "#{k}=#{tags[k]}" if values.include?(tags[k]) }
        nil
      end
    end
  end
end
