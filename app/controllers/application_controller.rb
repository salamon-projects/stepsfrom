class ApplicationController < ActionController::Base
  include Pagy::Method
  include PageViewTracking

  helper_method :current_stay, :prices_loading?

  private

  # Sends a request for a page past the end of the results to the last page.
  def redirect_past_last_page(pagy)
    return false unless pagy.page > pagy.last

    query = request.query_parameters.merge("page" => pagy.last).to_query
    redirect_to "#{request.path}?#{query}"
    true
  end

  # The visitor's dates, when they entered valid ones.
  # Prices for the visitor's dates are being fetched in the background and
  # the page has not reloaded for them yet (it reloads once, see the layout).
  def prices_loading?
    @prices_pending == true && params[:priced].blank?
  end

  def current_stay
    return @current_stay if defined?(@current_stay)

    stay = Stay.from_params(params)
    @current_stay = stay&.valid? ? stay : nil
  end
end
