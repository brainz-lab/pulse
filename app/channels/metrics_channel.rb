class MetricsChannel < ApplicationCable::Channel
  def subscribed
    project_id = params[:project_id]
    stream_from "metrics_#{project_id}"
  end

  def unsubscribed
    stop_all_streams
  end

  # Broadcast helpers for use throughout the application
  class << self
    def broadcast_trace(project, trace)
      ActionCable.server.broadcast(
        "metrics_#{project.id}",
        {
          type: "trace",
          trace: trace_payload(trace)
        }
      )
    end

    def broadcast_metric(project, metric_point)
      ActionCable.server.broadcast(
        "metrics_#{project.id}",
        {
          type: "metric",
          metric: {
            name: metric_point.metric.name,
            value: metric_point.value,
            timestamp: metric_point.timestamp
          }
        }
      )
    end

    private

    def trace_payload(trace)
      {
        id: trace.id,
        name: trace.name,
        kind: trace.kind,
        duration_ms: trace.duration_ms,
        status: trace.status,
        error: trace.error,
        started_at: trace.started_at
      }
    end
  end
end
