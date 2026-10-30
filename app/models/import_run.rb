# Progress and outcome of one import of a destination's data (see
# OsmImportJob). Steps are the import's layers followed by measuring.
class ImportRun < ApplicationRecord
  STATUSES = %w[queued running retrying succeeded failed].freeze
  ACTIVE_STATUSES = %w[queued running retrying].freeze
  # A run that has not moved for this long is treated as interrupted, so a
  # restart during an import does not block new imports forever. One Overpass
  # query with all its retries can take about half an hour.
  STALE_AFTER = 1.hour

  belongs_to :destination

  enum :status, STATUSES.index_by(&:itself), validate: true

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: ACTIVE_STATUSES).where(updated_at: STALE_AFTER.ago..) }

  def self.latest_by_destination
    where(id: select("DISTINCT ON (destination_id) id").order(:destination_id, created_at: :desc)).index_by(&:destination_id)
  end

  def active?
    status.in?(ACTIVE_STATUSES) && updated_at > STALE_AFTER.ago
  end

  def interrupted?
    status.in?(ACTIVE_STATUSES) && !active?
  end

  def start!(attempt:)
    update!(status: "running", attempts: attempt, started_at: started_at || Time.current, error: nil)
  end

  def progress!(step, done, total)
    update_columns(step:, steps_done: done, steps_total: total, updated_at: Time.current)
  end

  def succeed!(counts)
    update!(status: "succeeded", counts:, step: nil, finished_at: Time.current)
  end

  def retrying!(message, retry_at:)
    update!(status: "retrying", error: "#{message} Trying again at #{retry_at.utc.strftime('%H:%M')} UTC.")
  end

  def fail!(message)
    update!(status: "failed", error: message, finished_at: Time.current)
  end

  def duration
    return unless started_at

    (finished_at || Time.current) - started_at
  end
end
