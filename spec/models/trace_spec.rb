require "rails_helper"

RSpec.describe Trace, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_many(:spans).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:trace_id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_inclusion_of(:kind).in_array(described_class::KINDS) }
    it { is_expected.to validate_presence_of(:started_at) }
  end

  describe "scopes" do
    describe ".requests" do
      it "returns only request traces" do
        request_trace = create(:trace, kind: "request")
        job_trace = create(:trace, :job)
        expect(described_class.requests).to include(request_trace)
        expect(described_class.requests).not_to include(job_trace)
      end
    end

    describe ".errors" do
      it "returns only errored traces" do
        ok_trace = create(:trace, error: false)
        err_trace = create(:trace, :error)
        expect(described_class.errors).to include(err_trace)
        expect(described_class.errors).not_to include(ok_trace)
      end
    end

    describe ".slow" do
      it "returns traces exceeding the threshold" do
        fast = create(:trace, :completed)
        slow = create(:trace, :slow)
        expect(described_class.slow(1500)).to include(slow)
        expect(described_class.slow(1500)).not_to include(fast)
      end
    end
  end

  describe "#complete!" do
    let(:trace) { create(:trace, started_at: 200.milliseconds.ago) }

    it "sets ended_at" do
      freeze_time do
        trace.complete!
        expect(trace.ended_at).to be_within(1.second).of(Time.current)
      end
    end

    it "calculates duration_ms from started_at to ended_at" do
      ended = trace.started_at + 0.3
      trace.complete!(ended_at: ended)
      expect(trace.duration_ms).to be_within(5).of(300)
    end

    it "sets error flag and message" do
      trace.complete!(error: true, error_class: "RuntimeError", error_message: "boom")
      expect(trace.error).to be true
      expect(trace.error_class).to eq("RuntimeError")
      expect(trace.error_message).to eq("boom")
    end
  end

  describe "#apdex_category" do
    let(:project) { create(:project, settings: { "apdex_t" => 0.5 }) }

    it "returns :satisfied when duration <= T" do
      trace = build(:trace, :completed, project: project, duration_ms: 400)
      expect(trace.apdex_category).to eq(:satisfied)
    end

    it "returns :tolerating when T < duration <= 4T" do
      trace = build(:trace, :completed, project: project, duration_ms: 1500)
      expect(trace.apdex_category).to eq(:tolerating)
    end

    it "returns :frustrated when duration > 4T" do
      trace = build(:trace, :completed, project: project, duration_ms: 2500)
      expect(trace.apdex_category).to eq(:frustrated)
    end

    it "accepts an explicit threshold parameter" do
      trace = build(:trace, :completed, project: project, duration_ms: 800)
      expect(trace.apdex_category(1.0)).to eq(:satisfied)
    end
  end

  describe "#waterfall" do
    it "returns spans in started_at order with offset" do
      trace = create(:trace, :completed)
      span1 = create(:span, trace: trace, project: trace.project,
                     started_at: trace.started_at + 0.01, duration_ms: 10)
      span2 = create(:span, trace: trace, project: trace.project,
                     started_at: trace.started_at + 0.05, duration_ms: 5)

      waterfall = trace.waterfall
      expect(waterfall.map { |s| s[:id] }).to eq([ span1.span_id, span2.span_id ])
      expect(waterfall.first[:offset_ms]).to be_within(1).of(10)
    end
  end

  describe "trace_id uniqueness" do
    it "rejects duplicate trace_ids" do
      existing = create(:trace)
      duplicate = build(:trace, trace_id: existing.trace_id)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:trace_id]).to be_present
    end

    it "allows duplicates when skip_uniqueness_validation is set" do
      existing = create(:trace)
      duplicate = build(:trace, trace_id: existing.trace_id, skip_uniqueness_validation: true)
      expect(duplicate).to be_valid
    end
  end
end
