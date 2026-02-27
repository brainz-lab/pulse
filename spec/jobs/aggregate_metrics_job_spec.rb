require "rails_helper"

RSpec.describe AggregateMetricsJob, type: :job do
  describe "#perform" do
    let(:project) { create(:project) }
    let!(:trace)  { create(:trace, project: project) }

    it "calls MetricsAggregator#aggregate_minute! with the trace's started_at" do
      aggregator = instance_double(MetricsAggregator)
      expect(MetricsAggregator).to receive(:new).with(project: project).and_return(aggregator)
      expect(aggregator).to receive(:aggregate_minute!).with(trace.started_at)
      described_class.perform_now(trace.id)
    end

    it "does nothing when the trace does not exist" do
      expect(MetricsAggregator).not_to receive(:new)
      expect { described_class.perform_now("nonexistent-id") }.not_to raise_error
    end

    it "does not raise when MetricsAggregator raises" do
      aggregator = instance_double(MetricsAggregator)
      allow(MetricsAggregator).to receive(:new).and_return(aggregator)
      allow(aggregator).to receive(:aggregate_minute!).and_raise(StandardError, "db error")
      expect { described_class.perform_now(trace.id) }.not_to raise_error
    end

    it "enqueues on the default queue" do
      expect(described_class.queue_name).to eq("default")
    end
  end
end
