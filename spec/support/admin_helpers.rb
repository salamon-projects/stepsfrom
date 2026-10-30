module AdminHelpers
  def sign_in_admin(username: "admin", password: "admin")
    post admin_login_path, params: { username:, password: }
  end
end

RSpec.configure { |config| config.include AdminHelpers, type: :request }
