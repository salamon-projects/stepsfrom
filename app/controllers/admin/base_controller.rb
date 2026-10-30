module Admin
  # Admin pages require signing in on /admin/login with ADMIN_USER /
  # ADMIN_PASSWORD (or credentials admin.user / admin.password). Development and
  # test fall back to admin / admin; production refuses sign-in until the
  # credentials are set. A sign-in lasts SESSION_TTL.
  class BaseController < ApplicationController
    SESSION_TTL = 12.hours

    layout "admin"

    before_action :require_admin
    helper_method :admin_signed_in?

    private

    def require_admin
      return if admin_signed_in?

      session[:admin_return_to] = request.fullpath if request.get? || request.head?
      redirect_to admin_login_path
    end

    def admin_signed_in?
      signed_in_at = session[:admin_signed_in_at]
      signed_in_at.present? && Time.zone.at(signed_in_at) > SESSION_TTL.ago
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
