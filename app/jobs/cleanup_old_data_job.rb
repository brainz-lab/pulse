class CleanupOldDataJob < ApplicationJob
  queue_as :low

  # Clean up old traces and metric points
  def perform
    retention_days = ENV.fetch('DATA_RETENTION_DAYS', 30).to_i

    # Clean up old traces
    old_traces = Trace.where('started_at < ?', retention_days.days.ago)
    deleted_traces = old_traces.delete_all
    Rails.logger.info("[CleanupOldDataJob] Deleted #{deleted_traces} old traces")

    # Clean up old metric points
    old_points = MetricPoint.where('timestamp < ?', retention_days.days.ago)
    deleted_points = old_points.delete_all
    Rails.logger.info("[CleanupOldDataJob] Deleted #{deleted_points} old metric points")

    # Clean up old aggregated metrics
    old_aggregates = AggregatedMetric.where('bucket < ?', retention_days.days.ago)
    deleted_aggregates = old_aggregates.delete_all
    Rails.logger.info("[CleanupOldDataJob] Deleted #{deleted_aggregates} old aggregated metrics")
  end
end
