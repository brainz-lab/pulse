class AddPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    # For error list views
    add_index :traces, [:project_id, :error, :started_at],
      name: "idx_traces_errors_lookup",
      where: "error = true"

    # For slow span analysis
    add_index :spans, [:project_id, :kind, :duration_ms],
      name: "idx_spans_kind_duration",
      order: { duration_ms: :desc }

    # For aggregated metric time-series dashboard queries
    add_index :aggregated_metrics, [:project_id, :name, :granularity, :bucket],
      name: "idx_agg_metrics_timeseries",
      order: { bucket: :desc }

    # For metric point cleanup and time-range queries
    add_index :metric_points, [:project_id, :timestamp],
      name: "idx_metric_points_cleanup",
      order: { timestamp: :desc }
  end
end
