module AdminHelper
  IMPORT_STEPS = {
    "coastline" => "Coastline", "inland_water" => "Lakes and rivers", "beaches" => "Beaches",
    "roads" => "Roads", "accommodations" => "Accommodation"
  }.freeze

  def import_status_badge(run)
    status = run.interrupted? ? "interrupted" : run.status
    tag.span(status.humanize, class: [ "import-status", "import-status--#{status}" ])
  end

  # One line on where an import stands or how it ended.
  def import_status_detail(run)
    if run.interrupted?
      "Stopped without finishing (probably a restart). Start it again."
    elsif run.queued?
      "Waiting to start…"
    elsif run.running?
      "#{import_step_label(run.step)} (step #{run.steps_done + 1} of #{run.steps_total || '?'})…"
    elsif run.retrying?
      run.error
    elsif run.succeeded?
      "Finished #{time_ago_in_words(run.finished_at)} ago in #{import_duration(run)} · #{import_counts(run)}"
    else
      "Failed #{time_ago_in_words(run.finished_at || run.updated_at)} ago: #{run.error.to_s.truncate(160)}"
    end
  end

  def import_step_label(step)
    return "Starting" if step.blank?
    return step.sub("measuring", "Measuring properties") if step.start_with?("measuring")

    IMPORT_STEPS.fetch(step, step.humanize)
  end

  def import_counts(run)
    counts = run.counts
    parts = [ pluralize(counts["accommodations"].to_i, "property"), pluralize(counts["coastline"].to_i, "coastline way"),
              pluralize(counts["beaches"].to_i, "beach"), pluralize(counts["roads"].to_i, "road") ]
    parts << "#{counts['measurement_failures']} could not be measured" if counts["measurement_failures"].to_i.positive?
    parts.join(", ")
  end

  # Relative time, with the exact UTC time on hover.
  def import_time(time)
    tag.time("#{time_ago_in_words(time)} ago", datetime: time.iso8601, title: time.utc.strftime("%-d %b %Y %H:%M UTC"))
  end

  def import_duration(run)
    seconds = run.duration.to_i
    seconds < 90 ? "#{seconds} s" : "#{(seconds / 60.0).round} min"
  end
end
