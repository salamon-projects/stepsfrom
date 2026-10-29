# Be sure to restart your server when you modify this file.

# Pages are server-rendered with no inline scripts; the only script is the
# Leaflet map, loaded from our own assets. Map tiles are images from the
# configured tile server.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self
    policy.connect_src :self
    policy.frame_ancestors :none
    policy.base_uri    :self
    policy.form_action :self
  end
end
