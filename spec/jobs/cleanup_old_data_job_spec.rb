require "rails_helper"

RSpec.describe CleanupOldDataJob, type: :job do
  describe "#perform" do
    let(:project) { create(:project) }

    before { stub_const("ENV", ENV.to_h.merge("DATA_RETENTION_DAYS" => "30")) }

    it "deletes traces older than the retention period" do
      create(:trace, project: project, started_at: 31.days.ago)
      create(:trace, project: project, started_at: 5.days.ago)

      expect {
        described_class.perform_now
      }.to change(Trace, :count).by(-1)
    end

    it "keeps traces within the retention period" do
      recent = create(:trace, project: project, started_at: 5.days.ago)

      described_class.perform_now

      expect(Trace.find_by(id: recent.id)).not_to be_nil
    end

    it "deletes metric points older than the retention period" do
      metric = create(:metric, project: project)
      create(:metric_point, project: project, metric: metric, timestamp: 31.days.ago)
      create(:metric_point, project: project, metric: metric, timestamp: 5.days.ago)

      expect {
        described_class.perform_now
      }.to change(MetricPoint, :count).by(-1)
    end

    it "deletes aggregated metrics older than the retention period" do
      create(:aggregated_metric, project: project, bucket: 31.days.ago)
      create(:aggregated_metric, project: project, bucket: 5.days.ago)

      expect {
        described_class.perform_now
      }.to change(AggregatedMetric, :count).by(-1)
    end

    it "does not raise when there is nothing to delete" do
      expect { described_class.perform_now }.not_to raise_error
    end

    it "respects the DATA_RETENTION_DAYS environment variable" do
      stub_const("ENV", ENV.to_h.merge("DATA_RETENTION_DAYS" => "7"))
      create(:trace, project: project, started_at: 8.days.ago)
      create(:trace, project: project, started_at: 3.days.ago)

      expect {
        described_class.perform_now
      }.to change(Trace, :count).by(-1)
    end

    it "enqueues on the low queue" do
      expect(described_class.queue_name).to eq("low")
    end
  end
end
