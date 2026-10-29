module ApplicationHelper
  include Pagy::Frontend

  def page_title
    [ content_for(:title).presence, t("site_name") ].compact.join(" · ")
  end

  def page_description
    content_for(:description).presence || t("tagline")
  end

  def canonical_url
    content_for(:canonical).presence || "#{request.base_url}#{request.path}"
  end

  def format_price(cents, currency = "EUR")
    number_to_currency(cents / 100.0, unit: currency == "EUR" ? "€" : "#{currency} ", precision: 0)
  end

  # Query parameters that carry the visitor's stay between pages.
  def stay_params
    current_stay ? current_stay.to_params : {}
  end

  def map_tag(data, css_class: "map", label: nil)
    tag.div(class: css_class, role: "img", "aria-label": label,
            data: { map: data.merge(tiles: Rails.configuration.x.map_tile_url).to_json })
  end
end
