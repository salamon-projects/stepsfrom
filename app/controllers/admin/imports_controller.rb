module Admin
  class ImportsController < BaseController
    def index
      @runs = ImportRun.includes(:destination).recent.limit(50)
    end
  end
end
