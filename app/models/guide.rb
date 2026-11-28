# A buyer-intent guide (/guides/:slug): editorial copy from config/guides.yml
# around a ranked list of one destination's published properties. The list
# and every figure in the copy come from the database, so the page stays true
# as stays are re-measured. Not stored.
class Guide
  DEFAULT_LIMIT = 15
  CONFIG_PATH = Rails.root.join("config/guides.yml")

  attr_reader :slug, :destination_slug, :title, :keyword, :heading, :link_text, :limit, :kinds, :exclude

  # Every configured guide, published or not. Fresh objects each call, since
  # a guide remembers its destination.
  def self.all
    config.map { |slug, entry| new(slug, entry) }
  end

  # Guides whose destination is published and lists at least one property of
  # the guide's kinds.
  def self.published
    all.select(&:published?)
  end

  def self.find_published(slug)
    all.find { |guide| guide.slug == slug.to_s }&.then { |guide| guide if guide.published? }
  end

  def self.for_destinations(destinations)
    slugs = Array(destinations).map(&:slug)
    all.select { |guide| slugs.include?(guide.destination_slug) }.select(&:published?)
  end

  def self.config
    if Rails.configuration.enable_reloading
      load_config
    else
      @config ||= load_config
    end
  end

  def self.load_config
    YAML.load_file(CONFIG_PATH).transform_values(&:freeze).freeze
  end
  private_class_method :load_config

  def initialize(slug, entry)
    @slug = slug.to_s
    @destination_slug = entry.fetch("destination")
    @title = entry.fetch("title")
    @keyword = entry["keyword"]
    @description = entry.fetch("description")
    @heading = entry.fetch("heading")
    @link_text = entry.fetch("link_text", @heading)
    @limit = entry.fetch("limit", DEFAULT_LIMIT)
    @kinds = entry["kinds"]&.map(&:to_s)&.freeze
    unknown = Array(@kinds) - Property::KINDS
    raise ArgumentError, "guide #{@slug}: unknown kinds #{unknown.join(', ')}" if unknown.any?
    @exclude = Array(entry["exclude"]).map(&:to_s).freeze
    @intro = Array(entry["intro"])
    @faq = Array(entry["faq"])
  end

  def to_param
    slug
  end

  def destination
    return @destination if defined?(@destination)

    @destination = Destination.published.find_by(slug: destination_slug)
  end

  def published?
    destination.present? && listed.exists?
  end

  def country
    Country.new(destination.country_code)
  end

  # Whether the guide ranks and counts this property (of its destination, of
  # its kinds, not excluded), for a property already known to be published.
  def counts?(property)
    property.destination_id == destination&.id && (kinds.nil? || kinds.include?(property.kind)) &&
      !exclude.include?(property.slug)
  end

  # The ranked stays: verified beachfront first, then by measured distance.
  def properties
    @properties ||= listed.by_waterfront.preload(:destination, :waterfront, :active_listings).limit(limit).to_a
  end

  def description
    fill(@description)
  end

  def intro
    @intro.map { |paragraph| fill(paragraph) }
  end

  # [[question, answer], ...]
  def faq
    @faq.map { |entry| [ fill(entry.fetch("question")), fill(entry.fetch("answer")) ] }
  end

  # The values the copy may use (see config/guides.yml).
  def facts
    @facts ||= begin
      counts = listed.joins(:waterfront).group("verifications.category").count
      closest = listed.joins(:waterfront).where.not(verifications: { distance_m: nil })
                      .reorder("verifications.distance_m", "properties.name").pick("properties.name", "verifications.distance_m")
      config = Waterfront.config
      total = counts.values.sum
      { destination: destination.name, country: country.name,
        sea: destination.sea_name.present? ? "the #{destination.sea_name}" : I18n.t("properties.water_kinds.sea"),
        listed: "#{total} #{total == 1 ? 'place' : 'places'} to stay", listed_count: total,
        direct: counts.fetch("direct", 0), near: counts.fetch("near", 0), walkable: counts.fetch("walkable", 0),
        shown: properties.size, closest_name: closest&.first, closest_m: closest&.last,
        closest: closest&.last&.zero? ? "right on the water" : "#{closest&.last} m from the water",
        **config.slice(:direct_max_m, :direct_beach_max_m, :beach_adjacent_m, :near_max_m, :walkable_max_m) }
    end
  end

  private

  # Everything the guide ranks and counts: the destination's published stays,
  # limited to the guide's kinds when it names any and without the properties
  # it excludes, so the figures in the copy describe the same set as the list.
  # Keep #counts? in step.
  def listed
    scope = Property.published.where(destination:)
    scope = scope.where(kind: kinds) if kinds
    exclude.any? ? scope.where.not(slug: exclude) : scope
  end

  def fill(text)
    I18n.interpolate(text, facts)
  end
end
