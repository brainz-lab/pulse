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
    aggregator = mock("aggregator")
    aggregator.expects(:aggregate_minute!).with(trace.started_at).once

    MetricsAggregator.stubs(:new).with(project: @project).returns(aggregator)

    AggregateMetricsJob.new.perform(trace.id)
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
    MetricsAggregator.stubs(:new).raises(StandardError, "Test error")

    # Should not raise error (errors are logged)
    assert_nothing_raised do
      AggregateMetricsJob.new.perform(trace.id)
    end
  end

  test "perform should call aggregator with correct project" do
    trace = create_test_trace(@project,
      duration_ms: 100,
      started_at: Time.current,
      ended_at: Time.current + 0.1
    )

    aggregator = mock("aggregator")
    aggregator.stubs(:aggregate_minute!)

    MetricsAggregator.expects(:new).with(project: @project).returns(aggregator)

    AggregateMetricsJob.new.perform(trace.id)
  end
end
