class ApplicationController < ActionController::Base
  include Pagy::Method

  helper_method :current_stay

  private

  # The visitor's dates, when they entered valid ones.
  def current_stay
    return @current_stay if defined?(@current_stay)

    stay = Stay.from_params(params)
    @current_stay = stay if stay&.valid?
  end
end
