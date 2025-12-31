require "test_helper"

class MetricPointTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
    @metric = create_test_metric(@project)
    @point = @metric.points.create!(
      project: @project,
      timestamp: Time.current,
      value: 42.0,
      tags: { "env" => "test" }
    )
  end

  test "should be valid with valid attributes" do
    assert @point.valid?
  end

  test "should require timestamp" do
    point = MetricPoint.new(
      project: @project,
      metric: @metric,
      value: 10.0
    )
    assert_not point.valid?
    assert_includes point.errors[:timestamp], "can't be blank"
  end

  test "should require value" do
    point = MetricPoint.new(
      project: @project,
      metric: @metric,
      timestamp: Time.current
    )
    assert_not point.valid?
    assert_includes point.errors[:value], "can't be blank"
  end

  test "should belong to project" do
    assert_equal @project, @point.project
  end

  test "should belong to metric" do
    assert_equal @metric, @point.metric
  end

  test "should store tags as JSONB" do
    tags = { "host" => "web-1", "region" => "us-east" }
    point = @metric.points.create!(
      project: @project,
      timestamp: Time.current,
      value: 100.0,
      tags: tags
    )

    point.reload
    assert_equal "web-1", point.tags["host"]
    assert_equal "us-east", point.tags["region"]
  end

  test "should allow null tags" do
    point = @metric.points.create!(
      project: @project,
      timestamp: Time.current,
      value: 50.0,
      tags: nil
    )

    assert point.valid?
  end

  test "should handle numeric values" do
    [ 0, 1, -1, 0.5, -0.5, 100.123, 1_000_000 ].each do |value|
      point = @metric.points.create!(
        project: @project,
        timestamp: Time.current,
        value: value,
        tags: {}
      )
      assert_equal value, point.value
    end
  end
end
