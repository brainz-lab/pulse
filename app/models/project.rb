class Project < ApplicationRecord
  has_many :traces, dependent: :destroy
  has_many :spans, dependent: :destroy
  has_many :metrics, dependent: :destroy
  has_many :metric_points, dependent: :destroy
  has_many :aggregated_metrics, dependent: :destroy
  has_many :notification_channels, dependent: :destroy
  has_many :alert_rules, dependent: :destroy
  has_many :alerts, dependent: :destroy

  validates :platform_project_id, presence: true, uniqueness: true

  def self.find_or_create_for_platform!(platform_project_id:, name: nil, environment: "live")
    find_or_create_by!(platform_project_id: platform_project_id) do |p|
      p.name = name
      p.environment = environment
    end
  end

  # Apdex score for a time range
  def apdex(since: 1.hour.ago)
    traces_in_range = traces.where("started_at >= ?", since).where(kind: "request")

    ApdexCalculator.calculate(
      traces: traces_in_range,
      threshold: apdex_t
    )
  end

  # Key metrics summary - optimized to use a single aggregate query
  def overview(since: 1.hour.ago)
    traces_scope = traces.where("started_at >= ?", since).where(kind: "request")

    # Single query to get all counts and averages to avoid N+1
    stats = traces_scope.pick(
      Arel.sql("COUNT(*)"),
      Arel.sql("AVG(duration_ms)"),
      Arel.sql("COUNT(*) FILTER (WHERE error = true)"),
      Arel.sql("COUNT(*) FILTER (WHERE duration_ms <= #{apdex_t * 1000})"),
      Arel.sql("COUNT(*) FILTER (WHERE duration_ms > #{apdex_t * 1000} AND duration_ms <= #{apdex_t * 4000})")
    )

    total, avg_duration, error_count, satisfied, tolerating = stats
    total ||= 0
    error_count ||= 0
    satisfied ||= 0
    tolerating ||= 0

    # Calculate Apdex from the aggregated counts
    apdex_score = total > 0 ? ((satisfied + (tolerating / 2.0)) / total).round(2) : 1.0

    # Get percentiles with a single query
    durations = traces_scope.where.not(duration_ms: nil).order(:duration_ms).pluck(:duration_ms)
    p95_duration = durations.any? ? durations[(durations.length * 0.95).to_i] : nil
    p99_duration = durations.any? ? durations[(durations.length * 0.99).to_i] : nil

    {
      apdex: apdex_score,
      throughput: total,
      rpm: total > 0 ? (total / ((Time.current - since) / 60.0)).round(1) : 0,
      avg_duration: avg_duration&.round(2),
      p95_duration: p95_duration,
      p99_duration: p99_duration,
      error_rate: total > 0 ? (error_count.to_f / total * 100).round(2) : 0,
      error_count: error_count
    }
  end

  private
end
