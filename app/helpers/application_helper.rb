module ApplicationHelper
  def page_title
    [ plain_content(:title), t("site_name") ].compact.join(" · ")
  end

  # The page's own title without the site name (og:title).
  def page_heading
    plain_content(:title) || t("site_name")
  end

  def page_description
    plain_content(:description) || t("tagline")
  end

  # content_for keeps text HTML-escaped ("Lloret de Mar &amp; Tossa"), and
  # HAML escapes again when it writes a tag or an attribute, which showed
  # "&amp;amp;" in titles and descriptions. This gives the plain text back,
  # to be escaped once.
  def plain_content(name)
    CGI.unescapeHTML(content_for(name).to_s).presence
  end

  def canonical_url
    # /destinations/x/ and /destinations/x are one page.
    content_for(:canonical).presence || "#{request.base_url}#{request.path.chomp('/').presence || '/'}"
  end

  def format_price(cents, currency = "EUR")
    number_to_currency(cents / 100.0, unit: currency == "EUR" ? "€" : "#{currency} ", precision: 0)
  end

  # Query parameters that carry the visitor's stay between pages.
  def stay_params
    current_stay ? current_stay.to_params : {}
  end

  # Only http(s) URLs become links; anything else is shown as text.
  def external_link(text, url)
    uri = URI.parse(url.to_s)
    return text unless uri.is_a?(URI::HTTP)

    link_to text, uri.to_s, rel: "noopener noreferrer", target: "_blank"
  rescue URI::InvalidURIError
    text
  end

  def map_tag(data, css_class: "map", label: nil)
    tag.div(class: css_class, role: "region", "aria-label": label,
            data: { map: data.merge(tiles: Rails.configuration.x.map_tile_url).to_json })
  end
end
