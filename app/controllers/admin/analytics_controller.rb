module Admin
  # Page views and click-outs over the last 1, 7 or 30 days (Analytics::Report).
  class AnalyticsController < BaseController
    def show
      @report = Analytics::Report.new(days: params[:days])
    end
  end
end
