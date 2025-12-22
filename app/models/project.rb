class Project < ApplicationRecord
  has_many :traces, dependent: :destroy
  has_many :spans, dependent: :destroy
  has_many :metrics, dependent: :destroy
  has_many :metric_points, dependent: :destroy
  has_many :aggregated_metrics, dependent: :destroy

  validates :platform_project_id, presence: true, uniqueness: true

  def self.find_or_create_for_platform!(platform_project_id:, name: nil, environment: 'live')
    find_or_create_by!(platform_project_id: platform_project_id) do |p|
      p.name = name
      p.environment = environment
    end
  end

  # Apdex score for a time range
  def apdex(since: 1.hour.ago)
    traces_in_range = traces.where('started_at >= ?', since).where(kind: 'request')

    ApdexCalculator.calculate(
      traces: traces_in_range,
      threshold: apdex_t
    )
  end

  # Key metrics summary
  def overview(since: 1.hour.ago)
    traces_scope = traces.where('started_at >= ?', since).where(kind: 'request')

    {
      apdex: apdex(since: since),
      throughput: traces_scope.count,
      rpm: (traces_scope.count / ((Time.current - since) / 60.0)).round(1),
      avg_duration: traces_scope.average(:duration_ms)&.round(2),
      p95_duration: percentile(traces_scope, :duration_ms, 0.95),
      p99_duration: percentile(traces_scope, :duration_ms, 0.99),
      error_rate: error_rate(traces_scope),
      error_count: traces_scope.where(error: true).count
    }
  end

  private

  def percentile(scope, column, p)
    scope.order(column).offset((scope.count * p).to_i).limit(1).pick(column)
  end

  def error_rate(scope)
    total = scope.count
    return 0 if total == 0
    (scope.where(error: true).count.to_f / total * 100).round(2)
  end
end
