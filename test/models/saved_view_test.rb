require "test_helper"

class SavedViewTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
  end

  test "valid with required attributes" do
    view = @project.saved_views.build(name: "My View", view_type: "requests")
    assert view.valid?
  end

  test "requires name" do
    view = @project.saved_views.build(view_type: "requests")
    assert_not view.valid?
    assert_includes view.errors[:name], "can't be blank"
  end

  test "requires view_type" do
    view = @project.saved_views.build(name: "My View")
    assert_not view.valid?
    assert_includes view.errors[:view_type], "can't be blank"
  end

  test "validates view_type inclusion" do
    view = @project.saved_views.build(name: "My View", view_type: "invalid")
    assert_not view.valid?
    assert_includes view.errors[:view_type], "is not included in the list"
  end

  test "accepts all valid view_types" do
    %w[requests endpoints queries overview].each do |type|
      view = @project.saved_views.build(name: "View #{type}", view_type: type)
      assert view.valid?, "Expected #{type} to be valid"
    end
  end

  test "belongs to project" do
    view = @project.saved_views.create!(name: "My View", view_type: "requests")
    assert_equal @project, view.project
  end

  test "pinned scope returns only pinned views" do
    pinned = @project.saved_views.create!(name: "Pinned", view_type: "requests", pinned: true)
    unpinned = @project.saved_views.create!(name: "Not Pinned", view_type: "requests", pinned: false)

    results = @project.saved_views.pinned
    assert_includes results, pinned
    assert_not_includes results, unpinned
  end

  test "for_type scope filters by view_type" do
    requests_view = @project.saved_views.create!(name: "Req View", view_type: "requests")
    endpoints_view = @project.saved_views.create!(name: "End View", view_type: "endpoints")

    results = @project.saved_views.for_type("requests")
    assert_includes results, requests_view
    assert_not_includes results, endpoints_view
  end

  test "stores filters as jsonb" do
    view = @project.saved_views.create!(
      name: "Filtered View",
      view_type: "requests",
      filters: { "since" => "1h", "errors" => true, "min_duration" => 500 }
    )

    view.reload
    assert_equal({ "since" => "1h", "errors" => true, "min_duration" => 500 }, view.filters)
  end

  test "defaults pinned to false" do
    view = @project.saved_views.create!(name: "Default", view_type: "requests")
    assert_equal false, view.pinned
  end

  test "defaults filters to empty hash" do
    view = @project.saved_views.create!(name: "Default", view_type: "requests")
    assert_equal({}, view.filters)
  end

  test "project has_many saved_views with dependent destroy" do
    @project.saved_views.create!(name: "View", view_type: "requests")
    assert_equal 1, @project.saved_views.count

    @project.destroy
    assert_equal 0, SavedView.where(project_id: @project.id).count
  end
end
