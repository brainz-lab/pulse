require "test_helper"

class SloCalculatorTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
  end

  test "calculates error_rate SLO" do
    create_traces(total: 100, errors: 5)

    slo = create_slo(target_metric: "error_rate", operator: "lte", threshold: 10.0)
    SloCalculator.new(slo: slo).calculate!

    slo.reload
    assert_equal 5.0, slo.current_value
    assert_not_nil slo.error_budget_remaining
    assert_not_nil slo.last_calculated_at
  end

  test "calculates availability SLO" do
    create_traces(total: 100, errors: 2)

    slo = create_slo(target_metric: "availability", operator: "gte", threshold: 99.0)
    SloCalculator.new(slo: slo).calculate!

    slo.reload
    assert_equal 98.0, slo.current_value
  end

  test "calculates p95 SLO" do
    100.times { |i| create_test_trace(@project, duration_ms: (i + 1) * 10.0, kind: "request", started_at: 1.minute.ago) }

    slo = create_slo(target_metric: "p95", operator: "lte", threshold: 1000.0)
    SloCalculator.new(slo: slo).calculate!

    slo.reload
    assert_not_nil slo.current_value
    assert slo.current_value > 0
  end

  test "calculates p99 SLO" do
    100.times { |i| create_test_trace(@project, duration_ms: (i + 1) * 10.0, kind: "request", started_at: 1.minute.ago) }

    slo = create_slo(target_metric: "p99", operator: "lte", threshold: 1000.0)
    SloCalculator.new(slo: slo).calculate!

    slo.reload
    assert_not_nil slo.current_value
    assert slo.current_value > 0
  end

  test "calculates apdex SLO" do
    # Satisfied traces (under 500ms threshold)
    10.times { create_test_trace(@project, duration_ms: 200.0, kind: "request", started_at: 1.minute.ago) }
    # Frustrated traces
    5.times { create_test_trace(@project, duration_ms: 5000.0, kind: "request", started_at: 1.minute.ago) }

    slo = create_slo(target_metric: "apdex", operator: "gte", threshold: 0.8)
    SloCalculator.new(slo: slo).calculate!

    slo.reload
    assert_not_nil slo.current_value
    # 10 satisfied + 0 tolerating/2 / 15 total = 0.67
    assert_equal 0.67, slo.current_value
  end

  test "error budget is 100% when within budget for lte operator" do
    create_traces(total: 100, errors: 0)

    slo = create_slo(target_metric: "error_rate", operator: "lte", threshold: 5.0)
    SloCalculator.new(slo: slo).calculate!

    slo.reload
    assert_equal 100.0, slo.error_budget_remaining
  end

  test "error budget decreases when approaching threshold for lte operator" do
    create_traces(total: 100, errors: 3)

    slo = create_slo(target_metric: "error_rate", operator: "lte", threshold: 5.0)
    SloCalculator.new(slo: slo).calculate!

    slo.reload
    # current_value = 3.0, threshold = 5.0, remaining = (5.0-3.0)/5.0 * 100 = 40.0
    assert_equal 40.0, slo.error_budget_remaining
  end

  test "error budget is 0% when budget exhausted for lte operator" do
    create_traces(total: 100, errors: 10)

    slo = create_slo(target_metric: "error_rate", operator: "lte", threshold: 5.0)
    SloCalculator.new(slo: slo).calculate!

    slo.reload
    assert_equal 0, slo.error_budget_remaining
  end

  test "error budget for gte operator when meeting target" do
    create_traces(total: 100, errors: 0)

    slo = create_slo(target_metric: "availability", operator: "gte", threshold: 99.0)
    SloCalculator.new(slo: slo).calculate!

    slo.reload
    assert_equal 100.0, slo.error_budget_remaining
  end

  test "handles empty data gracefully" do
    slo = create_slo(target_metric: "error_rate", operator: "lte", threshold: 5.0)
    SloCalculator.new(slo: slo).calculate!

    slo.reload
    assert_equal 0.0, slo.current_value
    assert_not_nil slo.last_calculated_at
  end

  test "filters by endpoint when specified" do
    10.times { create_test_trace(@project, name: "GET /api/users", duration_ms: 100.0, kind: "request", started_at: 1.minute.ago) }
    10.times { create_test_trace(@project, name: "GET /api/orders", duration_ms: 5000.0, kind: "request", started_at: 1.minute.ago, error: true) }

    slo = create_slo(target_metric: "error_rate", operator: "lte", threshold: 5.0, endpoint: "GET /api/users")
    SloCalculator.new(slo: slo).calculate!

    slo.reload
    assert_equal 0.0, slo.current_value
  end

  test "burn_rate is zero when no recent violations" do
    create_traces(total: 100, errors: 0)

    slo = create_slo(target_metric: "error_rate", operator: "lte", threshold: 5.0)
    SloCalculator.new(slo: slo).calculate!

    slo.reload
    assert_equal 0.0, slo.burn_rate
  end

  private

  def create_traces(total:, errors:)
    (total - errors).times do
      create_test_trace(@project, duration_ms: 100.0, kind: "request", started_at: 1.minute.ago, error: false)
    end
    errors.times do
      create_test_trace(@project, duration_ms: 100.0, kind: "request", started_at: 1.minute.ago, error: true)
    end
  end

  def create_slo(attrs = {})
    @project.service_level_objectives.create!({
      name: "Test SLO",
      target_metric: "error_rate",
      operator: "lte",
      threshold: 5.0,
      window_days: 30
    }.merge(attrs))
  end
end
