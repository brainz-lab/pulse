require "rails_helper"

RSpec.describe TraceProcessor do
  let(:project) { create(:project) }

  before do
    allow(ActionCable.server).to receive(:broadcast)
    allow(AggregateMetricsJob).to receive(:perform_later)
  end

  describe "#process!" do
    let(:payload) do
      {
        "trace_id" => "trace-abc-123",
        "name" => "GET /api/v1/users",
        "kind" => "request",
        "started_at" => 500.milliseconds.ago.iso8601(3),
        "request_method" => "GET",
        "request_path" => "/api/v1/users",
        "status" => 200
      }
    end

    it "creates a new trace" do
      expect {
        described_class.new(project: project, payload: payload).process!
      }.to change(Trace, :count).by(1)
    end

    it "assigns the correct attributes" do
      trace = described_class.new(project: project, payload: payload).process!
      expect(trace.trace_id).to eq("trace-abc-123")
      expect(trace.name).to eq("GET /api/v1/users")
      expect(trace.kind).to eq("request")
    end

    it "returns the existing trace when trace_id already exists" do
      existing = create(:trace, project: project, trace_id: "trace-abc-123")
      result = described_class.new(project: project, payload: payload).process!
      expect(result.id).to eq(existing.id)
      expect(Trace.count).to eq(1)
    end

    context "with ended_at in the payload" do
      let(:started) { 300.milliseconds.ago }
      let(:ended)   { Time.current }
      let(:payload_with_end) do
        payload.merge(
          "started_at" => started.iso8601(3),
          "ended_at"   => ended.iso8601(3)
        )
      end

      it "completes the trace and calculates duration" do
        trace = described_class.new(project: project, payload: payload_with_end).process!
        expect(trace.ended_at).not_to be_nil
        expect(trace.duration_ms).to be_within(10).of(300)
      end

      it "enqueues AggregateMetricsJob" do
        described_class.new(project: project, payload: payload_with_end).process!
        expect(AggregateMetricsJob).to have_received(:perform_later)
      end
    end

    context "with error information" do
      let(:error_payload) do
        payload.merge(
          "ended_at"      => Time.current.iso8601(3),
          "error"         => true,
          "error_class"   => "ActiveRecord::RecordNotFound",
          "error_message" => "Couldn't find User"
        )
      end

      it "marks the trace as errored" do
        trace = described_class.new(project: project, payload: error_payload).process!
        expect(trace.error).to be true
        expect(trace.error_class).to eq("ActiveRecord::RecordNotFound")
        expect(trace.error_message).to eq("Couldn't find User")
      end
    end

    context "with spans in the payload" do
      let(:payload_with_spans) do
        payload.merge(
          "ended_at" => Time.current.iso8601(3),
          "spans" => [
            {
              "span_id"    => "span-001",
              "name"       => "SELECT users",
              "kind"       => "db",
              "started_at" => 400.milliseconds.ago.iso8601(3),
              "ended_at"   => 380.milliseconds.ago.iso8601(3),
              "duration_ms" => 20.0,
              "data"       => { "sql" => "SELECT * FROM users WHERE id = 1", "table" => "users" }
            }
          ]
        )
      end

      it "creates spans for the trace" do
        expect {
          described_class.new(project: project, payload: payload_with_spans).process!
        }.to change(Span, :count).by(1)
      end

      it "assigns the span_id correctly" do
        described_class.new(project: project, payload: payload_with_spans).process!
        expect(Span.last.span_id).to eq("span-001")
      end
    end

    context "with a job trace" do
      let(:job_payload) do
        {
          "trace_id"  => "job-trace-001",
          "kind"      => "job",
          "job_class" => "ProcessOrderJob",
          "started_at" => 1.second.ago.iso8601(3)
        }
      end

      it "builds the name from job_class" do
        trace = described_class.new(project: project, payload: job_payload).process!
        expect(trace.name).to eq("ProcessOrderJob")
      end
    end

    context "when the same trace_id is inserted concurrently (race)" do
      it "returns the trace that won the race instead of raising RecordNotUnique" do
        existing = create(:trace, project: project, trace_id: "trace-abc-123")

        # Simulate the TOCTOU window: the existence check misses, but by the
        # time we INSERT another request has already written the row, so the
        # unique index raises. Ingestion must stay idempotent.
        relation = project.traces
        allow(project).to receive(:traces).and_return(relation)
        allow(relation).to receive(:find_by).with(trace_id: "trace-abc-123").and_return(nil, existing)

        result = nil
        expect {
          result = described_class.new(project: project, payload: payload).process!
        }.not_to change(Trace, :count)
        expect(result.id).to eq(existing.id)
      end
    end
  end

  describe ".process_batch!" do
    def payload_for(trace_id, started_at: Time.current)
      {
        "trace_id" => trace_id,
        "name" => "GET /api/v1/users",
        "kind" => "request",
        "started_at" => started_at.iso8601(3),
        "status" => 200
      }
    end

    it "collapses duplicate trace_ids within a single batch to one row" do
      started = Time.current
      payloads = [ payload_for("dup-trace", started_at: started), payload_for("dup-trace", started_at: started) ]

      expect {
        described_class.process_batch!(project: project, payloads: payloads)
      }.to change(Trace, :count).by(1)

      expect(project.traces.where(trace_id: "dup-trace").count).to eq(1)
    end

    it "skips trace_ids that already exist instead of raising" do
      create(:trace, project: project, trace_id: "already-here")

      expect {
        described_class.process_batch!(project: project, payloads: [ payload_for("already-here") ])
      }.not_to change(Trace, :count)
    end

    it "inserts genuinely new traces" do
      expect {
        described_class.process_batch!(project: project, payloads: [ payload_for("brand-new") ])
      }.to change(Trace, :count).by(1)
    end
  end

  describe "path normalization" do
    it "replaces numeric IDs with :id" do
      processor = described_class.new(project: project, payload: {})
      normalized = processor.send(:normalize_path, "/api/v1/users/42/posts/99")
      expect(normalized).to eq("/api/v1/users/:id/posts/:id")
    end

    it "replaces UUIDs with :uuid" do
      uuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
      processor = described_class.new(project: project, payload: {})
      normalized = processor.send(:normalize_path, "/api/v1/projects/#{uuid}/secrets")
      expect(normalized).to eq("/api/v1/projects/:uuid/secrets")
    end
  end

  describe "timestamp parsing" do
    let(:processor) { described_class.new(project: project, payload: {}) }

    it "parses ISO8601 strings" do
      ts = "2024-01-15T10:30:00.000Z"
      result = processor.send(:parse_timestamp, ts)
      expect(result).to be_a(Time)
    end

    it "handles Time objects directly" do
      t = Time.current
      expect(processor.send(:parse_timestamp, t)).to eq(t)
    end

    it "handles Unix epoch numerics" do
      epoch = Time.current.to_i
      result = processor.send(:parse_timestamp, epoch)
      expect(result).to be_a(Time)
    end

    it "returns nil for nil input" do
      expect(processor.send(:parse_timestamp, nil)).to be_nil
    end

    it "returns nil for unparseable strings" do
      expect(processor.send(:parse_timestamp, "not-a-date")).to be_nil
    end
  end
end
