module Waterfront
  def self.config
    @config ||= Rails.application.config_for(:waterfront)
  end
end
