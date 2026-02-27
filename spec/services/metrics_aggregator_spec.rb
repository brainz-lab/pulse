require "rails_helper"

RSpec.describe MetricsAggregator do
  let(:project) { create(:project) }
  let(:bucket)  { Time.current.beginning_of_minute }
  let(:aggregator) { described_class.new(project: project) }

  describe "#aggregate_minute!" do
    context "with request traces in the bucket" do
      before do
        # 3 request traces in the target minute
        create(:trace, :completed, project: project, duration_ms: 100, started_at: bucket + 10.seconds)
        create(:trace, :completed, project: project, duration_ms: 200, started_at: bucket + 20.seconds)
        create(:trace, :error,     project: project, duration_ms: 50,  started_at: bucket + 30.seconds)
      end

      it "creates a request_duration aggregate" do
        aggregator.aggregate_minute!(bucket)
        agg = AggregatedMetric.find_by(project: project, name: "request_duration", bucket: bucket, granularity: "minute")
        expect(agg).not_to be_nil
        expect(agg.count).to eq(3)
        expect(agg.avg).to be_within(1).of(116.67)
      end

      it "creates a throughput aggregate" do
        aggregator.aggregate_minute!(bucket)
        agg = AggregatedMetric.find_by(project: project, name: "throughput", bucket: bucket, granularity: "minute")
        expect(agg).not_to be_nil
        expect(agg.count).to eq(1)
        expect(agg.sum).to eq(3)
      end

      it "creates an error_rate aggregate" do
        aggregator.aggregate_minute!(bucket)
        agg = AggregatedMetric.find_by(project: project, name: "error_rate", bucket: bucket, granularity: "minute")
        expect(agg).not_to be_nil
        # 1 error out of 3 = 33.33%
        expect(agg.sum).to be_within(0.1).of(33.33)
      end
    end

    context "with job traces in the bucket" do
      before do
        create(:trace, :job, project: project, duration_ms: 500, started_at: bucket + 5.seconds, ended_at: bucket + 5.seconds + 0.5)
        create(:trace, :job, project: project, duration_ms: 300, started_at: bucket + 10.seconds, ended_at: bucket + 10.seconds + 0.3)
      end

      it "creates job_duration and job_count aggregates" do
        aggregator.aggregate_minute!(bucket)
        expect(AggregatedMetric.where(project: project, name: "job_duration", granularity: "minute")).to exist
        expect(AggregatedMetric.where(project: project, name: "job_count",    granularity: "minute")).to exist
      end
    end

    context "with no traces in the bucket" do
      it "does not create any aggregates" do
        expect {
          aggregator.aggregate_minute!(bucket)
        }.not_to change(AggregatedMetric, :count)
      end
    end
  end

  describe "extract_path_prefix (private)" do
    it "extracts the first two path segments" do
      result = aggregator.send(:extract_path_prefix, "GET /api/v1/users")
      expect(result).to eq("/api/v1")
    end

    it "returns nil for single-segment paths" do
      expect(aggregator.send(:extract_path_prefix, "GET /health")).to be_nil
    end

    it "returns nil for blank input" do
      expect(aggregator.send(:extract_path_prefix, nil)).to be_nil
      expect(aggregator.send(:extract_path_prefix, "")).to be_nil
    end
  end

  describe "percentile calculation (private)" do
    it "returns the correct p95 value" do
      values = (1..100).to_a
      result = aggregator.send(:percentile, values, 0.95)
      expect(result).to eq(95)
    end

    it "returns nil for an empty array" do
      expect(aggregator.send(:percentile, [], 0.95)).to be_nil
    end
  end
end
