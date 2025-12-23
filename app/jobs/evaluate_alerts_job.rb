class EvaluateAlertsJob < ApplicationJob
  queue_as :default

  def perform(project_id = nil)
    if project_id
      project = Project.find_by(id: project_id)
      evaluate_project(project) if project
    else
      # Evaluate all projects
      Project.find_each do |project|
        evaluate_project(project)
      end
    end
  end

  private

  def evaluate_project(project)
    AlertEvaluator.new(project: project).evaluate_all!
  rescue StandardError => e
    Rails.logger.error("[EvaluateAlertsJob] Error evaluating project #{project.id}: #{e.message}")
  end
end
