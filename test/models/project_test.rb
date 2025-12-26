require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
  end

  test "should be valid with valid attributes" do
    assert @project.valid?
  end

  test "should require platform_project_id" do
    project = Project.new(name: "Test")
    assert_not project.valid?
    assert_includes project.errors[:platform_project_id], "can't be blank"
  end

  test "should require unique platform_project_id" do
    duplicate = Project.new(platform_project_id: @project.platform_project_id)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:platform_project_id], "has already been taken"
  end

  test "should have many traces" do
    trace = create_test_trace(@project)
    assert_includes @project.traces, trace
  end

  test "should have many spans" do
    trace = create_test_trace(@project, ended_at: Time.current, duration_ms: 100)
    span = create_test_span(trace)
    assert_includes @project.spans, span
  end

  test "should have many metrics" do
    metric = create_test_metric(@project)
    assert_includes @project.metrics, metric
  end

  test "should destroy associated records on destroy" do
    trace = create_test_trace(@project, ended_at: Time.current, duration_ms: 100)
    span = create_test_span(trace)
    metric = create_test_metric(@project)

    trace_id = trace.id
    span_id = span.id
    metric_id = metric.id

    @project.destroy

    assert_nil Trace.find_by(id: trace_id)
    assert_nil Span.find_by(id: span_id)
    assert_nil Metric.find_by(id: metric_id)
  end

  test "find_or_create_for_platform! should find existing project" do
    platform_id = @project.platform_project_id
    found = Project.find_or_create_for_platform!(platform_project_id: platform_id)
    assert_equal @project.id, found.id
  end

  test "find_or_create_for_platform! should create new project" do
    new_platform_id = SecureRandom.uuid
    project = Project.find_or_create_for_platform!(
      platform_project_id: new_platform_id,
      name: "New Project",
      environment: "production"
    )

    assert project.persisted?
    assert_equal new_platform_id, project.platform_project_id
    assert_equal "New Project", project.name
    assert_equal "production", project.environment
  end

  test "apdex should calculate correctly" do
    # Create traces with different durations
    # Satisfied: <= 500ms (0.5s threshold)
    create_test_trace(@project, duration_ms: 200, started_at: 30.minutes.ago, ended_at: 30.minutes.ago)
    create_test_trace(@project, duration_ms: 400, started_at: 30.minutes.ago, ended_at: 30.minutes.ago)

    # Tolerating: 500ms < x <= 2000ms
    create_test_trace(@project, duration_ms: 1000, started_at: 30.minutes.ago, ended_at: 30.minutes.ago)

    # Frustrated: > 2000ms
    create_test_trace(@project, duration_ms: 3000, started_at: 30.minutes.ago, ended_at: 30.minutes.ago)

    # Apdex = (2 + 1/2) / 4 = 2.5 / 4 = 0.625, rounded to 0.63
    apdex = @project.apdex(since: 1.hour.ago)
    assert_equal 0.63, apdex
  end

  test "overview should return metrics summary" do
    # Create some test traces
    create_test_trace(@project,
      duration_ms: 100,
      started_at: 10.minutes.ago,
      ended_at: 10.minutes.ago,
      error: false
    )

    create_test_trace(@project,
      duration_ms: 200,
      started_at: 10.minutes.ago,
      ended_at: 10.minutes.ago,
      error: true
    )

    overview = @project.overview(since: 1.hour.ago)

    assert_kind_of Hash, overview
    assert_includes overview, :apdex
    assert_includes overview, :throughput
    assert_includes overview, :rpm
    assert_includes overview, :avg_duration
    assert_includes overview, :error_rate
    assert_includes overview, :error_count

    assert_equal 2, overview[:throughput]
    assert_equal 1, overview[:error_count]
    assert_equal 50.0, overview[:error_rate]
  end

  test "overview should return zero values for empty project" do
    overview = @project.overview(since: 1.hour.ago)

    assert_equal 1.0, overview[:apdex]  # Default Apdex when no traces
    assert_equal 0, overview[:throughput]
    assert_equal 0, overview[:error_count]
  end
end
