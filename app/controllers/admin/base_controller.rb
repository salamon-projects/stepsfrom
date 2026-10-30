module Admin
  # HTTP Basic auth with ADMIN_USER / ADMIN_PASSWORD (or credentials
  # admin.user / admin.password). Development and test fall back to
  # admin / admin; production refuses access until credentials are set.
  class BaseController < ApplicationController
    layout "admin"

    before_action :authenticate_admin

    private

    def authenticate_admin
      user, password = admin_credentials
      return render(plain: "Admin credentials are not configured.", status: :service_unavailable) if user.blank? || password.blank?

      authenticate_or_request_with_http_basic("StepsFrom admin") do |given_user, given_password|
        ActiveSupport::SecurityUtils.secure_compare(given_user, user) &
          ActiveSupport::SecurityUtils.secure_compare(given_password, password)
      end
    end

    # Surrounding whitespace is ignored: a secret pasted with a trailing newline
    # must not lock the admin out.
    def admin_credentials
      user = ENV["ADMIN_USER"].to_s.strip.presence || Rails.application.credentials.dig(:admin, :user)
      password = ENV["ADMIN_PASSWORD"].to_s.strip.presence || Rails.application.credentials.dig(:admin, :password)
      return [ user, password ] if user.present? && password.present?

      Rails.env.local? ? %w[admin admin] : [ nil, nil ]
    end
  end
end
