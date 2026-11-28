# Daily deletion of page views older than PageView.retention_days
# (PAGE_VIEW_RETENTION_DAYS or config/analytics.yml, default 180).
class PurgePageViewsJob < ApplicationJob
  queue_as :default

  def perform
    PageView.purge_expired
  end
end
