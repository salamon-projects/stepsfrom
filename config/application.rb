require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Beachfrontworld
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Price providers to query (see app/services/prices.rb), e.g. "stay22,agoda"
    # once an adapter exists for an approved programme.
    config.x.price_providers = ENV.fetch("PRICE_PROVIDERS", "").split(",").map(&:strip).compact_blank

    # Map tiles; the default is the OpenStreetMap tile server, which is fine for
    # low traffic but see https://operations.osmfoundation.org/policies/tiles/
    config.x.map_tile_url = ENV.fetch("MAP_TILE_URL", "https://tile.openstreetmap.org/{z}/{x}/{y}.png")

    config.generators do |g|
      g.template_engine :haml
      g.test_framework :rspec, fixtures: false, view_specs: false, helper_specs: false, routing_specs: false
      g.factory_bot dir: "spec/factories"
      g.system_tests nil
    end
  end
end
