require "test_helper"

class CleanupOldDataJobTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
  end

  test "perform should delete traces older than retention period" do
    old_trace = create_test_trace(@project,
      started_at: 45.days.ago,
      ended_at: 45.days.ago,
      duration_ms: 100
    )
    recent_trace = create_test_trace(@project,
      started_at: 1.day.ago,
      ended_at: 1.day.ago,
      duration_ms: 100
    )

    CleanupOldDataJob.new.perform

    assert_nil Trace.find_by(id: old_trace.id)
    assert_not_nil Trace.find_by(id: recent_trace.id)
  end

  test "perform should delete metric points older than retention period" do
    metric = create_test_metric(@project)

    old_point = metric.points.create!(
      project: @project,
      timestamp: 45.days.ago,
      value: 100.0,
      tags: {}
    )
    recent_point = metric.points.create!(
      project: @project,
      timestamp: 1.day.ago,
      value: 100.0,
      tags: {}
    )

    CleanupOldDataJob.new.perform

    assert_nil MetricPoint.find_by(id: old_point.id)
    assert_not_nil MetricPoint.find_by(id: recent_point.id)
  end

  test "perform should delete aggregated metrics older than retention period" do
    old_aggregate = @project.aggregated_metrics.create!(
      name: "response_time",
      bucket: 45.days.ago.beginning_of_hour,
      granularity: "hour"
    )
    recent_aggregate = @project.aggregated_metrics.create!(
      name: "response_time",
      bucket: 1.day.ago.beginning_of_hour,
      granularity: "hour"
    )

    CleanupOldDataJob.new.perform

    assert_nil AggregatedMetric.find_by(id: old_aggregate.id)
    assert_not_nil AggregatedMetric.find_by(id: recent_aggregate.id)
  end

  test "perform should use configurable retention days" do
    # Create trace at 20 days ago (would be deleted with default 30 days, but not with 15 days)
    trace_20_days = create_test_trace(@project,
      started_at: 20.days.ago,
      ended_at: 20.days.ago,
      duration_ms: 100
    )

    # Create trace at 40 days ago (should be deleted with custom 15 day retention)
    trace_40_days = create_test_trace(@project,
      started_at: 40.days.ago,
      ended_at: 40.days.ago,
      duration_ms: 100
    )

    # Test with custom retention (15 days)
    ENV["DATA_RETENTION_DAYS"] = "15"
    CleanupOldDataJob.new.perform

    assert_nil Trace.find_by(id: trace_20_days.id)
    assert_nil Trace.find_by(id: trace_40_days.id)
  ensure
    ENV.delete("DATA_RETENTION_DAYS")
  end

  test "perform should handle empty tables gracefully" do
    # Ensure no data exists
    Trace.delete_all
    MetricPoint.delete_all
    AggregatedMetric.delete_all

    assert_nothing_raised do
      CleanupOldDataJob.new.perform
    end
  end

  test "perform should be assigned to low queue" do
    job = CleanupOldDataJob.new
    assert_equal "low", job.queue_name
  end
end
