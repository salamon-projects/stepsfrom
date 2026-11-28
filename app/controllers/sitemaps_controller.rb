# sitemap.xml: home and the guides, then the other hubs, then properties best
# waterfront first (verified beachfront, then steps from the water, then a
# short walk), each with a lastmod from when its content last changed.
class SitemapsController < ApplicationController
  def show
    @destinations = Destination.published.ordered.to_a
    properties = Property.published.where(destination: @destinations).by_waterfront
                         .select(:id, :slug, :destination_id, :kind, "verifications.category AS waterfront_category",
                                 "GREATEST(properties.updated_at, verifications.updated_at) AS content_updated_at").to_a

    # A destination page changes with the stays it lists; a country page and
    # the home page with their destinations.
    newest = properties.group_by(&:destination_id).transform_values { |listed| listed.map(&:content_updated_at).max }
    @lastmods = @destinations.to_h { |destination| [ destination, [ destination.updated_at, newest[destination.id] ].compact.max ] }
    @countries = Country.published.to_h do |country|
      [ country, @lastmods.filter_map { |destination, time| time if destination.country_code == country.code }.max ]
    end
    @site_lastmod = @lastmods.values.max
    # A guide changes with the stays it ranks and counts (its copy is filled
    # from them): its destination's, of its kinds, without those it excludes.
    @guides = Guide.published.to_h do |guide|
      [ guide, properties.select { |property| guide.counts?(property) }.map(&:content_updated_at).max ]
    end
    @properties = exclude_walkable? ? properties.reject { |property| property.waterfront_category == "walkable" } : properties
  end

  private

  # SITEMAP_EXCLUDE_WALKABLE=1 leaves "Short walk to the water" stays out of
  # the sitemap (their pages stay public and indexable).
  def exclude_walkable?
    ActiveModel::Type::Boolean.new.cast(ENV["SITEMAP_EXCLUDE_WALKABLE"].presence) || false
  end
end
