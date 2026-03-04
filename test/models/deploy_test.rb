require "test_helper"

class DeployTest < ActiveSupport::TestCase
  def setup
    @project = create_test_project
  end

  test "valid deploy with required attributes" do
    deploy = @project.deploys.build(
      version: "1.0.0",
      deployed_at: Time.current
    )
    assert deploy.valid?
  end

  test "requires version" do
    deploy = @project.deploys.build(deployed_at: Time.current)
    assert_not deploy.valid?
    assert_includes deploy.errors[:version], "can't be blank"
  end

  test "requires deployed_at" do
    deploy = @project.deploys.build(version: "1.0.0")
    assert_not deploy.valid?
    assert_includes deploy.errors[:deployed_at], "can't be blank"
  end

  test "belongs to project" do
    deploy = @project.deploys.create!(
      version: "1.0.0",
      deployed_at: Time.current
    )
    assert_equal @project, deploy.project
  end

  test "recent scope orders by deployed_at desc" do
    old = @project.deploys.create!(version: "1.0.0", deployed_at: 2.hours.ago)
    new_deploy = @project.deploys.create!(version: "2.0.0", deployed_at: 1.hour.ago)

    results = @project.deploys.recent
    assert_equal new_deploy, results.first
    assert_equal old, results.last
  end

  test "since scope filters by deployed_at" do
    old = @project.deploys.create!(version: "1.0.0", deployed_at: 3.hours.ago)
    recent = @project.deploys.create!(version: "2.0.0", deployed_at: 30.minutes.ago)

    results = @project.deploys.since(1.hour.ago)
    assert_includes results, recent
    assert_not_includes results, old
  end

  test "stores optional attributes" do
    deploy = @project.deploys.create!(
      version: "1.0.0",
      commit_sha: "abc123",
      deployed_by: "deployer@example.com",
      environment: "production",
      description: "Bug fix release",
      metadata: { "pipeline_id" => 42 },
      deployed_at: Time.current
    )

    deploy.reload
    assert_equal "abc123", deploy.commit_sha
    assert_equal "deployer@example.com", deploy.deployed_by
    assert_equal "production", deploy.environment
    assert_equal "Bug fix release", deploy.description
    assert_equal({ "pipeline_id" => 42 }, deploy.metadata)
  end

  test "project has_many deploys with dependent destroy" do
    @project.deploys.create!(version: "1.0.0", deployed_at: Time.current)
    assert_equal 1, @project.deploys.count

    @project.destroy
    assert_equal 0, Deploy.where(project_id: @project.id).count
  end
end
