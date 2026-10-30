module Admin
  class SessionsController < BaseController
    skip_before_action :require_admin, only: %i[new create]
    before_action :require_configured_credentials, only: %i[new create]

    rate_limit to: 10, within: 3.minutes, only: :create,
               with: -> { redirect_to admin_login_path, alert: "Too many attempts. Try again in a few minutes." }

    def new
      redirect_to admin_root_path if admin_signed_in?
    end

    def create
      if valid_credentials?(params[:username], params[:password])
        return_to = session[:admin_return_to]
        reset_session
        session[:admin_signed_in_at] = Time.current.to_i
        redirect_to safe_return_path(return_to) || admin_root_path
      else
        flash.now[:alert] = "Wrong username or password."
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      reset_session
      redirect_to admin_login_path, notice: "Signed out."
    end

    private

    def require_configured_credentials
      return if admin_credentials.all?(&:present?)

      render plain: "Admin credentials are not configured.", status: :service_unavailable
    end

    def valid_credentials?(username, password)
      user, expected_password = admin_credentials
      ActiveSupport::SecurityUtils.secure_compare(username.to_s.strip, user) &
        ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected_password)
    end

    # Only admin paths on this site; never an outside URL.
    def safe_return_path(path)
      path if path.is_a?(String) && path.start_with?("/admin") && !path.start_with?("//")
    end
  end
end
