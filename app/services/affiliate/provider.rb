module Affiliate
  # A booking site we link to, configured in config/affiliates.yml.
  class Provider
    attr_reader :key, :name, :logo, :params, :child_params, :child_age, :child_age_separator, :tracking_env

    def self.all
      @all ||= Rails.application.config_for(:affiliates).to_h.map { |key, attrs| new(key.to_s, attrs) }.index_by(&:key)
    end

    def self.keys
      all.keys
    end

    def self.find(key)
      all[key.to_s]
    end

    def initialize(key, attrs)
      @key = key
      @name = attrs.fetch(:name)
      @logo = attrs[:logo]
      @host_pattern = Regexp.new(attrs.fetch(:host_pattern))
      @params = attrs.fetch(:params, {}).transform_keys(&:to_s)
      @child_params = attrs.fetch(:child_params, {}).transform_keys(&:to_s)
      @child_age = attrs.fetch(:child_age, "{age}")
      @child_age_separator = attrs.fetch(:child_age_separator, ",")
      @tracking_env = attrs[:tracking_env]
    end

    def accepts_url?(url)
      uri = URI.parse(url)
      uri.is_a?(URI::HTTP) && uri.host.present? && @host_pattern.match?(uri.host.downcase)
    rescue URI::InvalidURIError
      false
    end

    def tracking_template
      template = ENV[tracking_env.to_s].presence if tracking_env
      template if template&.include?("{url}")
    end

    def tracking_configured?
      tracking_template.present?
    end
  end
end
