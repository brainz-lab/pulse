require "test_helper"

class AggregateMetricsJobTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
  end

  test "perform should aggregate metrics for trace" do
    trace = create_test_trace(@project,
      duration_ms: 100,
      started_at: Time.current,
      ended_at: Time.current + 0.1
    )

    # Mock the MetricsAggregator
    aggregator = Minitest::Mock.new
    aggregator.expect :aggregate_minute!, nil, [ trace.started_at ]

    MetricsAggregator.stub :new, aggregator do
      AggregateMetricsJob.new.perform(trace.id)
    end

    aggregator.verify
  end

  test "perform should handle non-existent trace gracefully" do
    # Should not raise error
    assert_nothing_raised do
      AggregateMetricsJob.new.perform("non-existent-id")
    end
  end

  test "perform should handle errors gracefully" do
    trace = create_test_trace(@project,
      duration_ms: 100,
      started_at: Time.current,
      ended_at: Time.current + 0.1
    )

    # Simulate an error in aggregation
    MetricsAggregator.stub :new, ->(_) { raise StandardError, "Test error" } do
      # Should not raise error (errors are logged)
      assert_nothing_raised do
        AggregateMetricsJob.new.perform(trace.id)
      end
    end
  end

  test "perform should call aggregator with correct project" do
    trace = create_test_trace(@project,
      duration_ms: 100,
      started_at: Time.current,
      ended_at: Time.current + 0.1
    )

    aggregator_called_with = nil
    MetricsAggregator.stub :new, ->(project:) {
      aggregator_called_with = project
      mock = Minitest::Mock.new
      mock.expect :aggregate_minute!, nil, [ trace.started_at ]
      mock
    } do
      AggregateMetricsJob.new.perform(trace.id)
    end

    assert_equal @project.id, aggregator_called_with.id
  end
end
