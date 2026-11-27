module Affiliate
  # Activity sites (tours, boat trips) linked from destination and guide pages,
  # configured in config/activities.yml. Each link is a search on the site for
  # the destination, carrying our partner ids. A site counts only while all of
  # its ids are set, so nothing is shown until a programme has approved us.
  module Activities
    Provider = Data.define(:key, :name, :search_url, :query_param, :env, :params, :campaign_param) do
      def configured?
        env.values.all? { |name| ENV[name].present? }
      end

      # The site's search for the destination, with our ids.
      def url(destination)
        query = [ [ query_param, Activities.search_term(destination) ] ]
        query.concat(env.map { |param, name| [ param, ENV[name].strip ] })
        query.concat(params.to_a)
        query << [ campaign_param, destination.slug.gsub(/[^A-Za-z0-9-]+/, "-") ] if campaign_param
        uri = URI.parse(search_url)
        uri.query = URI.encode_www_form(query)
        uri.to_s
      end
    end

    def self.providers
      @providers ||= config.fetch(:providers).map do |key, attrs|
        Provider.new(key: key.to_s, name: attrs.fetch(:name), search_url: attrs.fetch(:search_url),
                     query_param: attrs.fetch(:query_param),
                     env: attrs.fetch(:env).to_h { |param, name| [ param.to_s, name.to_s ] }.freeze,
                     params: attrs.fetch(:params, {}).to_h { |param, value| [ param.to_s, value.to_s ] }.freeze,
                     campaign_param: attrs[:campaign_param])
      end.freeze
    end

    # The sites whose ids are set, in button order.
    def self.configured
      providers.select(&:configured?)
    end

    def self.find_configured(key)
      configured.find { |provider| provider.key == key.to_s }
    end

    def self.search_term(destination)
      config.fetch(:search_terms, {})[destination.slug.to_sym].presence || destination.name
    end

    def self.config
      @config ||= Rails.application.config_for(:activities)
    end
    private_class_method :config
  end
end
