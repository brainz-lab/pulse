class AggregateMetricsJob < ApplicationJob
  queue_as :default

  def perform(trace_id)
    trace = Trace.find_by(id: trace_id)
    return unless trace

    aggregator = MetricsAggregator.new(project: trace.project)
    aggregator.aggregate_minute!(trace.started_at)
  rescue => e
    Rails.logger.error("[AggregateMetricsJob] Failed: #{e.message}")
  end
end
