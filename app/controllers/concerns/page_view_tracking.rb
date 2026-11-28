# Counts successful HTML page views of the public site, server-side and
# without cookies (see PageView). Bots, Do-Not-Track / Global Privacy Control
# requests, prefetches, the automatic reload that shows fresh prices, and the
# admin, outbound redirects and machine-readable paths are not counted.
# Recording is one INSERT; any error is logged and swallowed so it can never
# break a page.
module PageViewTracking
  extend ActiveSupport::Concern

  SKIPPED_PATHS = %r{\A/(admin|go|up|assets|rails|sitemap\.xml|robots\.txt)(/|\z)}

  included do
    after_action :record_page_view
  end

  private

  def record_page_view
    return unless count_page_view?

    PageView.insert(PageView.attributes_for(request))
  rescue StandardError => error
    Rails.logger.warn("Page view not recorded: #{error.class}: #{error.message}")
  end

  def count_page_view?
    request.request_method == "GET" &&
      response.status == 200 &&
      response.media_type == "text/html" &&
      !request.path.match?(SKIPPED_PATHS) &&
      request.query_parameters["priced"].blank? &&
      !opted_out? && !prefetch? &&
      !PageView.bot?(request.user_agent)
  end

  def opted_out?
    request.headers["DNT"] == "1" || request.headers["Sec-GPC"] == "1"
  end

  def prefetch?
    [ request.headers["Sec-Purpose"], request.headers["Purpose"], request.headers["X-Moz"] ].compact.any? { |value| value.include?("prefetch") }
  end
end
