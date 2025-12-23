module Dashboard
  class DevToolsController < ApplicationController
    layout 'dashboard'
    before_action :ensure_development!

    def show
      @stats = {
        projects: Project.count,
        traces: Trace.count,
        spans: Span.count,
        metrics: Metric.count,
        metric_points: MetricPoint.count,
        aggregated_metrics: AggregatedMetric.count
      }
    end

    def clean_traces
      # Delete in correct order due to foreign key constraints (spans -> traces)
      spans_count = Span.delete_all
      traces_count = Trace.delete_all
      aggregated_count = AggregatedMetric.delete_all

      redirect_to dashboard_dev_tools_path, notice: "Cleaned #{traces_count} traces, #{spans_count} spans, #{aggregated_count} aggregated metrics"
    end

    def clean_all
      # Delete in correct order due to foreign key constraints
      spans_count = Span.delete_all
      traces_count = Trace.delete_all
      metric_points_count = MetricPoint.delete_all
      metrics_count = Metric.delete_all
      aggregated_count = AggregatedMetric.delete_all
      alerts_count = Alert.delete_all
      alert_rules_count = AlertRule.delete_all

      counts = {
        spans: spans_count,
        traces: traces_count,
        metric_points: metric_points_count,
        metrics: metrics_count,
        aggregated_metrics: aggregated_count,
        alerts: alerts_count,
        alert_rules: alert_rules_count
      }

      redirect_to dashboard_dev_tools_path, notice: "Cleaned all data: #{counts.map { |k, v| "#{v} #{k}" }.join(', ')}"
    end

    private

    def ensure_development!
      unless Rails.env.development?
        redirect_to dashboard_root_path, alert: "Dev tools only available in development"
      end
    end
  end
end
