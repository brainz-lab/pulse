require "test_helper"

class ServiceLevelObjectiveTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
  end

  test "valid with required attributes" do
    slo = build_slo
    assert slo.valid?
  end

  test "requires name" do
    slo = build_slo(name: nil)
    assert_not slo.valid?
    assert_includes slo.errors[:name], "can't be blank"
  end

  test "requires target_metric" do
    slo = build_slo(target_metric: nil)
    assert_not slo.valid?
    assert_includes slo.errors[:target_metric], "can't be blank"
  end

  test "requires operator" do
    slo = build_slo(operator: nil)
    assert_not slo.valid?
    assert_includes slo.errors[:operator], "can't be blank"
  end

  test "requires threshold" do
    slo = build_slo(threshold: nil)
    assert_not slo.valid?
    assert_includes slo.errors[:threshold], "can't be blank"
  end

  test "validates target_metric inclusion" do
    slo = build_slo(target_metric: "invalid")
    assert_not slo.valid?
    assert_includes slo.errors[:target_metric], "is not included in the list"
  end

  test "validates operator inclusion" do
    slo = build_slo(operator: "invalid")
    assert_not slo.valid?
    assert_includes slo.errors[:operator], "is not included in the list"
  end

  test "accepts all valid target_metrics" do
    %w[apdex error_rate p95 p99 availability].each do |metric|
      slo = build_slo(target_metric: metric)
      assert slo.valid?, "Expected #{metric} to be valid"
    end
  end

  test "accepts all valid operators" do
    %w[lt lte gt gte].each do |op|
      slo = build_slo(operator: op)
      assert slo.valid?, "Expected #{op} to be valid"
    end
  end

  test "belongs to project" do
    slo = create_slo
    assert_equal @project, slo.project
  end

  test "enabled scope returns only enabled SLOs" do
    enabled = create_slo(enabled: true)
    disabled = create_slo(name: "Disabled SLO", enabled: false)

    results = @project.service_level_objectives.enabled
    assert_includes results, enabled
    assert_not_includes results, disabled
  end

  test "due_for_calculation scope returns uncalculated and stale SLOs" do
    never_calculated = create_slo(name: "Never Calculated")
    stale = create_slo(name: "Stale", last_calculated_at: 10.minutes.ago)
    fresh = create_slo(name: "Fresh", last_calculated_at: 1.minute.ago)

    results = ServiceLevelObjective.due_for_calculation(5.minutes)
    assert_includes results, never_calculated
    assert_includes results, stale
    assert_not_includes results, fresh
  end

  test "project has_many service_level_objectives with dependent destroy" do
    create_slo
    assert_equal 1, @project.service_level_objectives.count

    @project.destroy
    assert_equal 0, ServiceLevelObjective.where(project_id: @project.id).count
  end

  private

  def build_slo(attrs = {})
    @project.service_level_objectives.build({
      name: "P95 Latency SLO",
      target_metric: "p95",
      operator: "lte",
      threshold: 500.0,
      window_days: 30
    }.merge(attrs))
  end

  def create_slo(attrs = {})
    @project.service_level_objectives.create!({
      name: "P95 Latency SLO",
      target_metric: "p95",
      operator: "lte",
      threshold: 500.0,
      window_days: 30
    }.merge(attrs))
  end
end
