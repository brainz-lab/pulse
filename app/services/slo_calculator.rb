class SloCalculator
  def initialize(slo:)
    @slo = slo
    @project = slo.project
  end

  def calculate!
    current = compute_current_value
    budget = compute_error_budget(current)
    burn = compute_burn_rate

    @slo.update!(
      current_value: current,
      error_budget_remaining: budget,
      burn_rate: burn,
      last_calculated_at: Time.current
    )
  end

  private

  def compute_current_value
    since = @slo.window_days.days.ago
    scope = @project.traces.where("started_at >= ?", since).where(kind: "request")
    scope = scope.where(name: @slo.endpoint) if @slo.endpoint.present?

    case @slo.target_metric
    when "error_rate"
      total = scope.count
      return 0.0 if total == 0
      (scope.where(error: true).count.to_f / total * 100).round(4)
    when "p95"
      scope.where.not(duration_ms: nil).pick(
        Arel.sql("PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms)")
      )&.round(2)
    when "p99"
      scope.where.not(duration_ms: nil).pick(
        Arel.sql("PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms)")
      )&.round(2)
    when "apdex"
      ApdexCalculator.calculate(traces: scope, threshold: @project.apdex_t)
    when "availability"
      total = scope.count
      return 100.0 if total == 0
      successful = scope.where(error: false).count
      (successful.to_f / total * 100).round(4)
    end
  end

  def compute_error_budget(current_value)
    return 100.0 unless current_value
    case @slo.operator
    when "lte"
      remaining = @slo.threshold - current_value
      (remaining / @slo.threshold * 100).round(2).clamp(0, 100)
    when "gte"
      return 100.0 if current_value >= @slo.threshold
      gap = @slo.threshold - current_value
      (100.0 - (gap / @slo.threshold * 100)).round(2).clamp(0, 100)
    else
      100.0
    end
  end

  def compute_burn_rate
    one_hour = compute_value_for_range(1.hour.ago)
    return 0.0 unless one_hour
    expected_budget_per_hour = 100.0 / (@slo.window_days * 24)
    return 0.0 if expected_budget_per_hour == 0
    actual_burn = case @slo.operator
    when "lte" then one_hour > @slo.threshold ? 1.0 : 0.0
    when "gte" then one_hour < @slo.threshold ? 1.0 : 0.0
    else 0.0
    end
    (actual_burn / expected_budget_per_hour).round(2)
  end

  def compute_value_for_range(since)
    scope = @project.traces.where("started_at >= ?", since).where(kind: "request")
    scope = scope.where(name: @slo.endpoint) if @slo.endpoint.present?
    total = scope.count
    return nil if total == 0
    case @slo.target_metric
    when "error_rate"
      (scope.where(error: true).count.to_f / total * 100).round(4)
    when "availability"
      (scope.where(error: false).count.to_f / total * 100).round(4)
    else
      nil
    end
  end
end
