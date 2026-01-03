require "test_helper"

class MetricsAggregatorTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
    @bucket = Time.current.beginning_of_minute
    @aggregator = MetricsAggregator.new(project: @project)
  end

  # Request aggregation tests
  test "aggregate_minute! should aggregate request durations" do
    create_test_trace(@project, started_at: @bucket + 10.seconds, duration_ms: 100, kind: "request")
    create_test_trace(@project, started_at: @bucket + 20.seconds, duration_ms: 200, kind: "request")
    create_test_trace(@project, started_at: @bucket + 30.seconds, duration_ms: 300, kind: "request")

    @aggregator.aggregate_minute!(@bucket)

    metric = @project.aggregated_metrics.find_by(name: "request_duration", bucket: @bucket)
    assert_not_nil metric
    assert_equal 3, metric.count
    assert_in_delta 600.0, metric.sum, 0.01
    assert_in_delta 100.0, metric.min, 0.01
    assert_in_delta 300.0, metric.max, 0.01
    assert_in_delta 200.0, metric.avg, 0.01
  end

  test "aggregate_minute! should calculate throughput" do
    5.times do |i|
      create_test_trace(@project, started_at: @bucket + i.seconds, duration_ms: 100, kind: "request")
    end

    @aggregator.aggregate_minute!(@bucket)

    metric = @project.aggregated_metrics.find_by(name: "throughput", bucket: @bucket)
    assert_not_nil metric
    assert_equal 1, metric.count
    assert_equal 5, metric.sum.to_i
  end

  test "aggregate_minute! should calculate error rate" do
    create_test_trace(@project, started_at: @bucket + 10.seconds, duration_ms: 100, kind: "request", error: false)
    create_test_trace(@project, started_at: @bucket + 20.seconds, duration_ms: 100, kind: "request", error: false)
    create_test_trace(@project, started_at: @bucket + 30.seconds, duration_ms: 100, kind: "request", error: true)
    create_test_trace(@project, started_at: @bucket + 40.seconds, duration_ms: 100, kind: "request", error: true)

    @aggregator.aggregate_minute!(@bucket)

    metric = @project.aggregated_metrics.find_by(name: "error_rate", bucket: @bucket)
    assert_not_nil metric
    assert_in_delta 50.0, metric.sum, 0.01
  end

  test "aggregate_minute! should skip traces without duration" do
    create_test_trace(@project, started_at: @bucket + 10.seconds, duration_ms: nil, kind: "request")
    create_test_trace(@project, started_at: @bucket + 20.seconds, duration_ms: 100, kind: "request")

    @aggregator.aggregate_minute!(@bucket)

    metric = @project.aggregated_metrics.find_by(name: "request_duration", bucket: @bucket)
    assert_not_nil metric
    assert_equal 1, metric.count
  end

  test "aggregate_minute! should not create metrics when no traces exist" do
    @aggregator.aggregate_minute!(@bucket)

    assert_equal 0, @project.aggregated_metrics.where(bucket: @bucket).count
  end

  # Endpoint aggregation tests
  test "aggregate_minute! should create endpoint metrics" do
    create_test_trace(@project, started_at: @bucket + 10.seconds, duration_ms: 100, kind: "request", name: "GET /users")
    create_test_trace(@project, started_at: @bucket + 20.seconds, duration_ms: 200, kind: "request", name: "GET /users")

    @aggregator.aggregate_minute!(@bucket)

    # Check that endpoint metrics were created
    endpoint_metrics = @project.aggregated_metrics.where(name: "endpoint_duration", bucket: @bucket)
    assert endpoint_metrics.exists?, "Should create endpoint_duration metrics"
  end

  test "aggregate_minute! should create endpoint throughput metrics" do
    3.times { |i| create_test_trace(@project, started_at: @bucket + i.seconds, duration_ms: 100, kind: "request", name: "GET /api/v1/users") }

    @aggregator.aggregate_minute!(@bucket)

    throughput_metrics = @project.aggregated_metrics.where(name: "endpoint_throughput", bucket: @bucket)
    assert throughput_metrics.exists?, "Should create endpoint_throughput metrics"
  end

  test "aggregate_minute! should create endpoint error rate metrics" do
    create_test_trace(@project, started_at: @bucket + 10.seconds, duration_ms: 100, kind: "request", name: "GET /users", error: false)
    create_test_trace(@project, started_at: @bucket + 20.seconds, duration_ms: 100, kind: "request", name: "GET /users", error: true)

    @aggregator.aggregate_minute!(@bucket)

    error_rate_metrics = @project.aggregated_metrics.where(name: "endpoint_error_rate", bucket: @bucket)
    assert error_rate_metrics.exists?, "Should create endpoint_error_rate metrics"
  end

  # Job aggregation tests
  test "aggregate_minute! should aggregate job durations" do
    create_test_trace(@project, started_at: @bucket + 10.seconds, duration_ms: 500, kind: "job", name: "ProcessOrderJob")
    create_test_trace(@project, started_at: @bucket + 20.seconds, duration_ms: 300, kind: "job", name: "SendEmailJob")

    @aggregator.aggregate_minute!(@bucket)

    metric = @project.aggregated_metrics.find_by(name: "job_duration", bucket: @bucket, dimensions: {})
    assert_not_nil metric
    assert_equal 2, metric.count
    assert_in_delta 800.0, metric.sum, 0.01
  end

  test "aggregate_minute! should calculate job count" do
    3.times do |i|
      create_test_trace(@project, started_at: @bucket + i.seconds, duration_ms: 100, kind: "job")
    end

    @aggregator.aggregate_minute!(@bucket)

    metric = @project.aggregated_metrics.find_by(name: "job_count", bucket: @bucket, dimensions: {})
    assert_not_nil metric
    assert_equal 3, metric.sum.to_i
  end

  test "aggregate_minute! should calculate job error rate" do
    create_test_trace(@project, started_at: @bucket + 10.seconds, duration_ms: 100, kind: "job", error: false)
    create_test_trace(@project, started_at: @bucket + 20.seconds, duration_ms: 100, kind: "job", error: true)

    @aggregator.aggregate_minute!(@bucket)

    metric = @project.aggregated_metrics.find_by(name: "job_error_rate", bucket: @bucket, dimensions: {})
    assert_in_delta 50.0, metric.sum, 0.01
  end

  # Percentile calculation tests
  test "should calculate percentiles correctly" do
    # Create 100 traces with durations 1-100ms
    100.times do |i|
      create_test_trace(@project, started_at: @bucket + (i * 0.5).seconds, duration_ms: i + 1, kind: "request")
    end

    @aggregator.aggregate_minute!(@bucket)

    metric = @project.aggregated_metrics.find_by(name: "request_duration", bucket: @bucket)
    assert_not_nil metric

    # p50 should be around 50
    assert_in_delta 50.0, metric.p50, 5.0
    # p95 should be around 95
    assert_in_delta 95.0, metric.p95, 5.0
    # p99 should be around 99
    assert_in_delta 99.0, metric.p99, 2.0
  end

  # Upsert behavior tests
  test "aggregate_minute! should upsert existing metrics" do
    create_test_trace(@project, started_at: @bucket + 10.seconds, duration_ms: 100, kind: "request")
    @aggregator.aggregate_minute!(@bucket)

    # Add more traces and re-aggregate
    create_test_trace(@project, started_at: @bucket + 20.seconds, duration_ms: 200, kind: "request")
    @aggregator.aggregate_minute!(@bucket)

    # Should have updated the existing record, not created a new one
    assert_equal 1, @project.aggregated_metrics.where(name: "request_duration", bucket: @bucket, dimensions: {}).count

    metric = @project.aggregated_metrics.find_by(name: "request_duration", bucket: @bucket)
    assert_equal 2, metric.count
  end

  # External HTTP aggregation tests
  test "aggregate_minute! should aggregate external HTTP calls" do
    trace = create_test_trace(@project, started_at: @bucket + 10.seconds, duration_ms: 100, kind: "request")
    create_test_span(trace, kind: "http", duration_ms: 50, data: { "host" => "api.stripe.com" })
    create_test_span(trace, kind: "http", duration_ms: 30, data: { "host" => "api.stripe.com" })

    @aggregator.aggregate_minute!(@bucket)

    # Check that external HTTP metrics were created
    http_duration = @project.aggregated_metrics.where(name: "external_http_duration", bucket: @bucket)
    http_count = @project.aggregated_metrics.where(name: "external_http_count", bucket: @bucket)

    assert http_duration.exists? || http_count.exists?, "Should create external HTTP metrics"
  end

  # Cache aggregation tests
  test "aggregate_minute! should aggregate cache operations" do
    trace = create_test_trace(@project, started_at: @bucket + 10.seconds, duration_ms: 100, kind: "request")
    create_test_span(trace, kind: "cache", duration_ms: 1, data: { "operation" => "read", "hit" => true })
    create_test_span(trace, kind: "cache", duration_ms: 1, data: { "operation" => "read", "hit" => true })
    create_test_span(trace, kind: "cache", duration_ms: 5, data: { "operation" => "read", "hit" => false })

    @aggregator.aggregate_minute!(@bucket)

    hit_rate = @project.aggregated_metrics.find_by(name: "cache_hit_rate", bucket: @bucket)
    assert_not_nil hit_rate
    # 2 hits out of 3 reads = 66.67%
    assert_in_delta 66.67, hit_rate.sum, 1.0

    hits = @project.aggregated_metrics.find_by(name: "cache_hits", bucket: @bucket)
    assert_equal 2, hits.sum.to_i

    misses = @project.aggregated_metrics.find_by(name: "cache_misses", bucket: @bucket)
    assert_equal 1, misses.sum.to_i
  end

  # Path prefix extraction tests
  test "extract_path_prefix should extract first two segments" do
    aggregator = MetricsAggregator.new(project: @project)

    assert_equal "/api/v1", aggregator.send(:extract_path_prefix, "GET /api/v1/users")
    assert_equal "/api/v2", aggregator.send(:extract_path_prefix, "POST /api/v2/orders/123")
    assert_equal "/admin/dashboard", aggregator.send(:extract_path_prefix, "/admin/dashboard/metrics")
  end

  test "extract_path_prefix should return nil for short paths" do
    aggregator = MetricsAggregator.new(project: @project)

    assert_nil aggregator.send(:extract_path_prefix, "/users")
    assert_nil aggregator.send(:extract_path_prefix, "GET /")
    assert_nil aggregator.send(:extract_path_prefix, nil)
    assert_nil aggregator.send(:extract_path_prefix, "")
  end
end
