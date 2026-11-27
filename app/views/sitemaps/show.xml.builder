xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  url = ->(loc, lastmod = nil) do
    xml.url do
      xml.loc loc
      xml.lastmod lastmod.utc.iso8601 if lastmod
    end
  end

  url.(root_url, @site_lastmod)
  @lastmods.each { |destination, lastmod| url.(destination_url(destination), lastmod) }
  @countries.each { |country, lastmod| url.(country_url(country), lastmod) }
  url.(how_we_verify_url)
  @properties.each { |property| url.(property_url(property), property.content_updated_at) }
end
