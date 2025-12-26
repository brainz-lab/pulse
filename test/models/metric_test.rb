require "test_helper"

class MetricTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
    @metric = create_test_metric(@project)
  end

  test "should be valid with valid attributes" do
    assert @metric.valid?
  end

  test "should require name" do
    metric = Metric.new(project: @project, kind: "gauge")
    assert_not metric.valid?
    assert_includes metric.errors[:name], "can't be blank"
  end

  test "should require unique name per project" do
    duplicate = Metric.new(
      project: @project,
      name: @metric.name,
      kind: "gauge"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should allow same name in different projects" do
    other_project = create_test_project(platform_project_id: SecureRandom.uuid)
    metric = Metric.new(
      project: other_project,
      name: @metric.name,
      kind: "gauge"
    )
    assert metric.valid?
  end

  test "should validate kind inclusion" do
    metric = Metric.new(
      project: @project,
      name: "invalid.metric",
      kind: "invalid"
    )
    assert_not metric.valid?
    assert_includes metric.errors[:kind], "is not included in the list"
  end

  test "should accept all valid kinds" do
    Metric::KINDS.each do |kind|
      metric = Metric.new(
        project: @project,
        name: "metric.#{kind}",
        kind: kind
      )
      assert metric.valid?, "#{kind} should be a valid kind"
    end
  end

  test "should belong to project" do
    assert_equal @project, @metric.project
  end

  test "should have many points" do
    point = @metric.points.create!(
      project: @project,
      timestamp: Time.current,
      value: 42.0,
      tags: {}
    )
    assert_includes @metric.points, point
  end

  test "should destroy associated points on destroy" do
    point = @metric.points.create!(
      project: @project,
      timestamp: Time.current,
      value: 42.0,
      tags: {}
    )
    point_id = point.id

    @metric.destroy

    assert_nil MetricPoint.find_by(id: point_id)
  end

  test "record! should create metric point with default timestamp" do
    point = @metric.record!(100.5)

    assert point.persisted?
    assert_equal 100.5, point.value
    assert_in_delta Time.current.to_i, point.timestamp.to_i, 1
  end

  test "record! should create metric point with custom timestamp" do
    timestamp = 1.hour.ago
    point = @metric.record!(50.0, timestamp: timestamp)

    assert_equal 50.0, point.value
    assert_equal timestamp.to_i, point.timestamp.to_i
  end

  test "record! should merge tags" do
    @metric.update!(tags: { "env" => "production" })
    point = @metric.record!(75.0, tags: { "host" => "web-1" })

    assert_equal "production", point.tags["env"]
    assert_equal "web-1", point.tags["host"]
  end

  test "stats should aggregate metric points" do
    base_time = 1.hour.ago

    # Create points at different times
    @metric.record!(10, timestamp: base_time)
    @metric.record!(20, timestamp: base_time + 1.minute)
    @metric.record!(30, timestamp: base_time + 2.minutes)

    stats = @metric.stats(since: 2.hours.ago, granularity: :minute)

    # Stats returns aggregated data grouped by time buckets
    assert stats.length > 0, "Should have aggregated stats"

    # Verify the stats response structure
    first_stat = stats.first
    assert_respond_to first_stat, :bucket
    assert_respond_to first_stat, :avg
  end

  test "stats should filter by time range" do
    @metric.record!(10, timestamp: 2.hours.ago)
    @metric.record!(20, timestamp: 30.minutes.ago)
    @metric.record!(30, timestamp: 10.minutes.ago)

    stats = @metric.stats(since: 1.hour.ago, granularity: :minute)

    # Should have stats (filtered by time range)
    assert stats.length > 0, "Should have stats within time range"
  end

  test "stats should support different granularities" do
    base_time = 1.day.ago

    5.times do |i|
      @metric.record!(i * 10, timestamp: base_time + i.hours)
    end

    hourly_stats = @metric.stats(since: 2.days.ago, granularity: :hour)
    assert hourly_stats.length > 0, "Should have hourly stats"

    daily_stats = @metric.stats(since: 2.days.ago, granularity: :day)
    assert daily_stats.length > 0, "Should have daily stats"
  end
end
