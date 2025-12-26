require "test_helper"

class EvaluateAlertsJobTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
  end

  test "perform should evaluate alerts for specific project" do
    evaluator = Minitest::Mock.new
    evaluator.expect :evaluate_all!, nil

    AlertEvaluator.stub :new, evaluator do
      EvaluateAlertsJob.new.perform(@project.id)
    end

    evaluator.verify
  end

  test "perform should evaluate alerts for all projects when no project_id given" do
    project1 = create_test_project(platform_project_id: "proj1")
    project2 = create_test_project(platform_project_id: "proj2")

    evaluated_projects = []

    AlertEvaluator.stub :new, ->(project:) {
      evaluated_projects << project.id
      mock = Minitest::Mock.new
      mock.expect :evaluate_all!, nil
      mock
    } do
      EvaluateAlertsJob.new.perform(nil)
    end

    # Should have evaluated both projects plus the setup project
    assert_includes evaluated_projects, project1.id
    assert_includes evaluated_projects, project2.id
  end

  test "perform should handle non-existent project gracefully" do
    # Should not raise error
    assert_nothing_raised do
      EvaluateAlertsJob.new.perform("non-existent-id")
    end
  end

  test "perform should handle evaluation errors gracefully" do
    # Simulate an error in evaluation
    AlertEvaluator.stub :new, ->(_) { raise StandardError, "Evaluation failed" } do
      # Should not raise error (errors are logged)
      assert_nothing_raised do
        EvaluateAlertsJob.new.perform(@project.id)
      end
    end
  end

  test "perform should continue evaluating other projects if one fails" do
    project1 = create_test_project(platform_project_id: "proj1")
    project2 = create_test_project(platform_project_id: "proj2")

    call_count = 0
    AlertEvaluator.stub :new, ->(project:) {
      call_count += 1
      # Fail on first project
      raise StandardError, "Test error" if project.id == project1.id

      mock = Minitest::Mock.new
      mock.expect :evaluate_all!, nil
      mock
    } do
      EvaluateAlertsJob.new.perform(nil)
    end

    # Should have attempted all projects despite one failing
    assert_operator call_count, :>=, 2
  end

  test "perform should call evaluator with correct project" do
    evaluator_called_with = nil
    AlertEvaluator.stub :new, ->(project:) {
      evaluator_called_with = project
      mock = Minitest::Mock.new
      mock.expect :evaluate_all!, nil
      mock
    } do
      EvaluateAlertsJob.new.perform(@project.id)
    end

    assert_equal @project.id, evaluator_called_with.id
  end
end
