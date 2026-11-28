module Analytics
  # Figures for the admin analytics page (/admin/analytics) over the last 1,
  # 7 or 30 days: page views (PageView) and click-outs (OutboundClick).
  #
  # Visitors are counted by PageView#visitor_hash, which changes every UTC
  # day, so one person visiting on three days counts three times: the figure
  # is "visitors, unique per day", summed over the range.
  class Report
    RANGES = [ 1, 7, 30 ].freeze
    DEFAULT_DAYS = 7
    TOP = 20
    VIEWS = Arel.sql("COUNT(*)")
    VISITORS = Arel.sql("COUNT(DISTINCT visitor_hash)")

    Row = Data.define(:label, :views, :visitors)
    Day = Data.define(:date, :views, :visitors, :clicks)
    PropertyClicks = Data.define(:property, :provider, :clicks)
    ActivityClicks = Data.define(:provider, :destination, :source_path, :clicks)
    GuideRate = Data.define(:path, :guide, :views, :clicks) do
      def rate
        clicks.fdiv(views) if views.positive?
      end
    end

    attr_reader :days, :from, :to

    def initialize(days: nil, now: Time.current)
      @days = RANGES.include?(days.to_i) ? days.to_i : DEFAULT_DAYS
      @to = now
      @from = now - @days.days
    end

    def page_views
      PageView.where(occurred_at: from..to)
    end

    def clicks
      OutboundClick.where(created_at: from..to)
    end

    def total_views
      @total_views ||= page_views.count
    end

    # Sum of each day's unique visitors (see the class comment).
    def visitors
      @visitors ||= page_views.distinct.count(:visitor_hash)
    end

    def total_clicks
      @total_clicks ||= clicks.count
    end

    # Click-outs per page view.
    def click_rate
      total_clicks.fdiv(total_views) if total_views.positive?
    end

    # One row per UTC day in the range, newest first.
    def daily
      views = page_views.group(Arel.sql("DATE(occurred_at)")).pluck(Arel.sql("DATE(occurred_at)"), VIEWS, VISITORS)
                        .to_h { |date, count, unique| [ date, [ count, unique ] ] }
      clicks_by_day = clicks.group(Arel.sql("DATE(created_at)")).count
      (from.utc.to_date..to.utc.to_date).reverse_each.map do |date|
        count, unique = views.fetch(date, [ 0, 0 ])
        Day.new(date:, views: count, visitors: unique, clicks: clicks_by_day.fetch(date, 0))
      end
    end

    def top_pages
      tally(page_views, :path)
    end

    def top_referrers
      tally(page_views.where.not(referrer_host: nil), :referrer_host)
    end

    # Rows labelled [source, medium, campaign].
    def utm_campaigns
      scope = page_views.where.not(utm_source: nil).or(page_views.where.not(utm_medium: nil))
                        .or(page_views.where.not(utm_campaign: nil))
      tally(scope, :utm_source, :utm_medium, :utm_campaign)
    end

    def countries
      tally(page_views.where.not(country: nil), :country)
    end

    def devices
      tally(page_views.where.not(device: nil), :device)
    end

    # Click-outs by site, booking and activity sites together: [key, count].
    def clicks_by_provider
      clicks.group(:provider).order(VIEWS.desc, :provider).count.to_a
    end

    # The properties (and booking sites) clicked out to most.
    def top_properties
      counts = clicks.where.not(property_id: nil).group(:property_id, :provider)
                     .order(VIEWS.desc, :property_id).limit(TOP).count
      properties = Property.where(id: counts.keys.map(&:first)).index_by(&:id)
      counts.filter_map do |(property_id, provider), count|
        property = properties[property_id] or next
        PropertyClicks.new(property:, provider:, clicks: count)
      end
    end

    # Clicks on "Things to do" (/go/activities/...), which record no listing:
    # by site and the page clicked on, with that page's destination.
    def activity_clicks
      counts = activity_scope.group(:provider, :source_path).order(VIEWS.desc, :provider, :source_path).count
      counts.map do |(provider, path), count|
        ActivityClicks.new(provider:, destination: destination_for(path), source_path: path, clicks: count)
      end
    end

    def activity_clicks_by_provider
      activity_scope.group(:provider).order(VIEWS.desc, :provider).count.to_a
    end

    # Page views of each guide page and the click-outs made from it, for
    # published guides and any guide path seen in the range.
    def guide_rates
      views = page_views.where("path LIKE ?", "/guides/%").group(:path).count
      clicks_by_path = clicks.where("source_path LIKE ?", "/guides/%").group(:source_path).count
      guides = Guide.all.index_by { |guide| "/guides/#{guide.slug}" }
      published = Guide.published.map { |guide| "/guides/#{guide.slug}" }
      (published + views.keys + clicks_by_path.keys).uniq.map do |path|
        GuideRate.new(path:, guide: guides[path], views: views.fetch(path, 0), clicks: clicks_by_path.fetch(path, 0))
      end.sort_by { |row| [ -row.views, -row.clicks, row.path ] }
    end

    def provider_name(key)
      Affiliate::Provider.find(key)&.name ||
        Affiliate::Activities.providers.find { |provider| provider.key == key }&.name || key
    end

    private

    def tally(scope, *columns)
      scope.group(*columns).order(VIEWS.desc, *columns).limit(TOP).pluck(*columns, VIEWS, VISITORS).map do |*labels, views, visitors|
        Row.new(label: columns.one? ? labels.first : labels, views:, visitors:)
      end
    end

    def activity_scope
      clicks.where(listing_id: nil, provider: Affiliate::Activities.providers.map(&:key))
    end

    # The destination of a destination or guide page path.
    def destination_for(path)
      kind, slug = path.to_s.match(%r{\A/(destinations|guides)/([^/]+)\z})&.captures
      slug = Guide.all.find { |guide| guide.slug == slug }&.destination_slug if kind == "guides"
      destinations[slug] if slug
    end

    def destinations
      @destinations ||= Destination.all.index_by(&:slug)
    end
  end
end
