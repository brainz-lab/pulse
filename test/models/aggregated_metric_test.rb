require "test_helper"

class AggregatedMetricTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
    @metric = @project.aggregated_metrics.create!(
      name: "request_duration",
      bucket: Time.current.beginning_of_minute,
      granularity: "minute",
      count: 100,
      sum: 5000.0,
      min: 10.0,
      max: 250.0,
      avg: 50.0,
      p50: 45.0,
      p95: 180.0,
      p99: 230.0
    )
  end

  test "should be valid with valid attributes" do
    assert @metric.valid?
  end

  test "should require name" do
    metric = AggregatedMetric.new(
      project: @project,
      bucket: Time.current,
      granularity: "minute"
    )
    assert_not metric.valid?
    assert_includes metric.errors[:name], "can't be blank"
  end

  test "should require bucket" do
    metric = AggregatedMetric.new(
      project: @project,
      name: "test",
      granularity: "minute"
    )
    assert_not metric.valid?
    assert_includes metric.errors[:bucket], "can't be blank"
  end

  test "should validate granularity inclusion" do
    metric = AggregatedMetric.new(
      project: @project,
      name: "test",
      bucket: Time.current,
      granularity: "invalid"
    )
    assert_not metric.valid?
    assert_includes metric.errors[:granularity], "is not included in the list"
  end

  test "should accept all valid granularities" do
    AggregatedMetric::GRANULARITIES.each do |granularity|
      metric = AggregatedMetric.new(
        project: @project,
        name: "test_#{granularity}",
        bucket: Time.current,
        granularity: granularity
      )
      assert metric.valid?, "#{granularity} should be a valid granularity"
    end
  end

  # Scopes
  test "scope for_range should filter by bucket range" do
    old_metric = @project.aggregated_metrics.create!(
      name: "request_duration",
      bucket: 2.hours.ago.beginning_of_minute,
      granularity: "minute"
    )
    recent_metric = @project.aggregated_metrics.create!(
      name: "request_duration",
      bucket: 30.minutes.ago.beginning_of_minute,
      granularity: "minute"
    )

    range_metrics = @project.aggregated_metrics.for_range(1.hour.ago)

    assert_includes range_metrics, @metric
    assert_includes range_metrics, recent_metric
    assert_not_includes range_metrics, old_metric
  end

  test "scope for_range should accept end time" do
    old_metric = @project.aggregated_metrics.create!(
      name: "request_duration",
      bucket: 3.hours.ago.beginning_of_minute,
      granularity: "minute"
    )

    range_metrics = @project.aggregated_metrics.for_range(4.hours.ago, 2.hours.ago)

    assert_includes range_metrics, old_metric
    assert_not_includes range_metrics, @metric
  end

  test "scope by_granularity should filter by granularity" do
    hourly_metric = @project.aggregated_metrics.create!(
      name: "request_duration",
      bucket: Time.current.beginning_of_hour,
      granularity: "hour"
    )

    minute_metrics = @project.aggregated_metrics.by_granularity("minute")
    hour_metrics = @project.aggregated_metrics.by_granularity("hour")

    assert_includes minute_metrics, @metric
    assert_not_includes minute_metrics, hourly_metric
    assert_includes hour_metrics, hourly_metric
    assert_not_includes hour_metrics, @metric
  end

  # Associations
  test "should belong to project" do
    assert_equal @project, @metric.project
  end

  # Dimensions (stored as JSON)
  test "should store dimensions as JSONB" do
    metric_with_dimensions = @project.aggregated_metrics.create!(
      name: "endpoint_duration",
      bucket: Time.current.beginning_of_minute,
      granularity: "minute",
      dimensions: { "endpoint" => "/api/users", "method" => "GET" }
    )

    metric_with_dimensions.reload
    assert_equal "/api/users", metric_with_dimensions.dimensions["endpoint"]
    assert_equal "GET", metric_with_dimensions.dimensions["method"]
  end

  # Numeric attributes
  test "should store statistical values" do
    assert_equal 100, @metric.count
    assert_in_delta 5000.0, @metric.sum, 0.01
    assert_in_delta 10.0, @metric.min, 0.01
    assert_in_delta 250.0, @metric.max, 0.01
    assert_in_delta 50.0, @metric.avg, 0.01
    assert_in_delta 45.0, @metric.p50, 0.01
    assert_in_delta 180.0, @metric.p95, 0.01
    assert_in_delta 230.0, @metric.p99, 0.01
  end

  test "should handle nil statistical values" do
    metric = @project.aggregated_metrics.create!(
      name: "empty_metric",
      bucket: Time.current.beginning_of_minute,
      granularity: "minute"
    )

    assert_nil metric.count
    assert_nil metric.sum
    assert_nil metric.min
    assert_nil metric.max
  end
end
