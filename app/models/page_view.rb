# One page seen by a visitor, counted without cookies (see PageViewTracking).
# Holds no IP address and no user agent: only the path, the referring site's
# host, UTM campaign parameters, a coarse device class, the country when a
# CDN supplies it, and visitor_hash, which a salt rotating every UTC day
# makes impossible to link across days. Purged after retention_days.
class PageView < ApplicationRecord
  UTM_LIMIT = 100
  HOST_LIMIT = 255
  PATH_LIMIT = 500
  HASH_LENGTH = 16
  MOBILE_PATTERN = /Mobi|Android|iPhone|iPad|iPod/i
  # Cloudflare's codes for unknown (XX) and Tor (T1) are not countries.
  COUNTRY_PATTERN = /\A(?!XX|T1)[A-Z]{2}\z/

  class << self
    # Attributes for a page view of the request, at time.
    def attributes_for(request, time: Time.current)
      params = request.query_parameters
      {
        occurred_at: time,
        path: request.path.to_s.first(PATH_LIMIT),
        referrer_host: referrer_host(request.referer, own_host: request.host),
        utm_source: utm(params["utm_source"]),
        utm_medium: utm(params["utm_medium"]),
        utm_campaign: utm(params["utm_campaign"]),
        country: request.headers["CF-IPCountry"].to_s.upcase.presence&.then { |code| code if code.match?(COUNTRY_PATTERN) },
        device: device(request.user_agent),
        visitor_hash: visitor_hash(ip: request.remote_ip, user_agent: request.user_agent, date: time.utc.to_date)
      }
    end

    # Anonymous id of a visitor for one UTC day: a truncated SHA-256 of a
    # salt derived from secret_key_base and the date, the IP address and the
    # user agent. Nothing is stored to make it, and once the day is over not
    # even we can tell which IP address produced it.
    def visitor_hash(ip:, user_agent:, date:)
      salt = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "page-views:#{date.iso8601}")
      Digest::SHA256.hexdigest([ salt, ip, user_agent ].join("\n")).first(HASH_LENGTH)
    end

    # Host of the referring page, nil when there is none or it is this site.
    def referrer_host(referer, own_host:)
      host = URI.parse(referer.to_s).host.to_s.downcase.delete_suffix(".").presence or return
      host unless bare_host(host) == bare_host(own_host.to_s.downcase)
    rescue URI::InvalidURIError
      nil
    end

    def utm(value)
      value.is_a?(String) ? value.strip.first(UTM_LIMIT).presence : nil
    end

    def device(user_agent)
      user_agent.to_s.match?(MOBILE_PATTERN) ? "mobile" : "desktop"
    end

    # Crawlers, link previews, monitors and HTTP libraries
    # (config/analytics.yml), and requests without a user agent.
    def bot?(user_agent)
      user_agent.blank? || bot_pattern.match?(user_agent)
    end

    def retention_days
      Integer(ENV["PAGE_VIEW_RETENTION_DAYS"].to_s.strip.presence || config.fetch(:retention_days, 180))
    end

    # Deletes page views older than retention_days, a batch at a time.
    def purge_expired(batch_size: 10_000)
      where(occurred_at: ...retention_days.days.ago).in_batches(of: batch_size).delete_all
    end

    private

    def bare_host(host)
      host.delete_prefix("www.")
    end

    def bot_pattern
      @bot_pattern ||= Regexp.union(config.fetch(:bot_user_agents).map { |word| Regexp.new(Regexp.escape(word.to_s), Regexp::IGNORECASE) })
    end

    def config
      @config ||= Rails.application.config_for(:analytics)
    end
  end
end
