require "rails_helper"

RSpec.describe EvaluateAlertsJob, type: :job do
  describe "#perform" do
    let!(:project) { create(:project) }

    it "calls AlertEvaluator#evaluate_all! for all projects when no project_id given" do
      evaluator = instance_double(AlertEvaluator)
      expect(AlertEvaluator).to receive(:new).with(project: project).and_return(evaluator)
      expect(evaluator).to receive(:evaluate_all!)
      described_class.perform_now
    end

    it "evaluates only the specified project when project_id is given" do
      other = create(:project)
      evaluator = instance_double(AlertEvaluator)
      expect(AlertEvaluator).to receive(:new).with(project: project).and_return(evaluator)
      expect(AlertEvaluator).not_to receive(:new).with(project: other)
      expect(evaluator).to receive(:evaluate_all!)
      described_class.perform_now(project.id)
    end

    it "does nothing when project_id is given but project does not exist" do
      expect(AlertEvaluator).not_to receive(:new)
      expect { described_class.perform_now("nonexistent-id") }.not_to raise_error
    end

    it "does not raise when AlertEvaluator raises a StandardError" do
      evaluator = instance_double(AlertEvaluator)
      allow(AlertEvaluator).to receive(:new).and_return(evaluator)
      allow(evaluator).to receive(:evaluate_all!).and_raise(StandardError, "boom")
      expect { described_class.perform_now }.not_to raise_error
    end

    it "evaluates all projects when multiple exist" do
      project2   = create(:project)
      evaluator  = instance_double(AlertEvaluator)
      evaluator2 = instance_double(AlertEvaluator)
      allow(AlertEvaluator).to receive(:new).with(project: project).and_return(evaluator)
      allow(AlertEvaluator).to receive(:new).with(project: project2).and_return(evaluator2)
      expect(evaluator).to receive(:evaluate_all!)
      expect(evaluator2).to receive(:evaluate_all!)
      described_class.perform_now
    end

    it "enqueues on the default queue" do
      expect(described_class.queue_name).to eq("default")
    end
  end
end
