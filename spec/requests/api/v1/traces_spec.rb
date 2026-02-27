require "rails_helper"

RSpec.describe "API V1 Traces", type: :request do
  let(:api_key) { "pls_testkey_traces_#{SecureRandom.hex(4)}" }
  let(:project) { create(:project, settings: { "api_key" => api_key }) }
  let(:headers) { auth_headers(project).merge("Content-Type" => "application/json") }

  before do
    allow(ActionCable.server).to receive(:broadcast)
    allow(AggregateMetricsJob).to receive(:perform_later)
  end

  # ──────────────────────────────────────────────
  # POST /api/v1/traces
  # ──────────────────────────────────────────────
  describe "POST /api/v1/traces" do
    let(:payload) do
      {
        trace_id: "trace-req-001",
        name: "GET /users",
        kind: "request",
        started_at: 200.milliseconds.ago.iso8601(3),
        request_method: "GET",
        request_path: "/users",
        status: 200
      }
    end

    it "creates a trace and returns 201" do
      expect {
        post "/api/v1/traces", params: payload.to_json, headers: headers
      }.to change(Trace, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "returns the trace_id in the response" do
      post "/api/v1/traces", params: payload.to_json, headers: headers
      expect(response.parsed_body["trace_id"]).to eq("trace-req-001")
    end

    it "creates spans when included in the payload" do
      payload_with_span = payload.merge(
        ended_at: Time.current.iso8601(3),
        spans: [
          {
            span_id: "span-001",
            name: "SELECT users",
            kind: "db",
            started_at: 150.milliseconds.ago.iso8601(3),
            duration_ms: 12.5,
            data: { sql: "SELECT * FROM users", table: "users" }
          }
        ]
      )

      expect {
        post "/api/v1/traces", params: payload_with_span.to_json, headers: headers
      }.to change(Span, :count).by(1)
    end

    it "completes the trace when ended_at is provided" do
      payload_with_end = payload.merge(ended_at: Time.current.iso8601(3))
      post "/api/v1/traces", params: payload_with_end.to_json, headers: headers

      trace = Trace.find_by(trace_id: "trace-req-001")
      expect(trace.ended_at).not_to be_nil
      expect(trace.duration_ms).to be > 0
    end

    context "without authentication" do
      it "returns 401" do
        post "/api/v1/traces", params: payload.to_json,
             headers: { "Content-Type" => "application/json" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with X-API-Key header" do
      it "also accepts the X-API-Key header" do
        post "/api/v1/traces", params: payload.merge(trace_id: "trace-xkey-001").to_json,
             headers: { "X-API-Key" => api_key, "Content-Type" => "application/json" }
        expect(response).to have_http_status(:created)
      end
    end
  end

  # ──────────────────────────────────────────────
  # POST /api/v1/traces/batch
  # ──────────────────────────────────────────────
  describe "POST /api/v1/traces/batch" do
    let(:batch_payload) do
      {
        traces: [
          {
            trace_id: "batch-trace-001",
            name: "GET /orders",
            kind: "request",
            started_at: 300.milliseconds.ago.iso8601(3),
            ended_at: Time.current.iso8601(3),
            status: 200
          },
          {
            trace_id: "batch-trace-002",
            name: "POST /orders",
            kind: "request",
            started_at: 200.milliseconds.ago.iso8601(3),
            ended_at: Time.current.iso8601(3),
            status: 201
          }
        ]
      }
    end

    it "creates multiple traces and returns 201" do
      expect {
        post "/api/v1/traces/batch", params: batch_payload.to_json, headers: headers
      }.to change(Trace, :count).by(2)

      expect(response).to have_http_status(:created)
    end

    it "returns the processed count" do
      post "/api/v1/traces/batch", params: batch_payload.to_json, headers: headers
      expect(response.parsed_body["processed"]).to eq(2)
      expect(response.parsed_body["results"].length).to eq(2)
    end

    it "returns 401 without authentication" do
      post "/api/v1/traces/batch", params: batch_payload.to_json,
           headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ──────────────────────────────────────────────
  # GET /api/v1/traces
  # ──────────────────────────────────────────────
  describe "GET /api/v1/traces" do
    before do
      create(:trace, :completed, project: project, kind: "request")
      create(:trace, :job,       project: project)
      create(:trace, :error,     project: project)
    end

    it "returns all traces up to the default limit" do
      get "/api/v1/traces", headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["traces"].length).to eq(3)
    end

    it "filters by kind" do
      get "/api/v1/traces", params: { filter_kind: "job" }, headers: headers
      kinds = response.parsed_body["traces"].map { |t| t["kind"] }
      expect(kinds).to all(eq("job"))
    end

    it "filters errored traces" do
      get "/api/v1/traces", params: { errors: "true" }, headers: headers
      traces = response.parsed_body["traces"]
      expect(traces).to all(include("error" => true))
    end

    it "respects the limit param" do
      get "/api/v1/traces", params: { limit: 2 }, headers: headers
      expect(response.parsed_body["traces"].length).to eq(2)
    end

    it "returns 401 without authentication" do
      get "/api/v1/traces"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ──────────────────────────────────────────────
  # GET /api/v1/traces/:id
  # ──────────────────────────────────────────────
  describe "GET /api/v1/traces/:id" do
    let(:trace) { create(:trace, :completed, project: project) }

    it "returns the trace with its waterfall" do
      get "/api/v1/traces/#{trace.trace_id}", headers: headers
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["trace"]["id"]).to eq(trace.id)
      expect(body["spans"]).to be_an(Array)
    end

    it "returns 404 for unknown trace_id" do
      get "/api/v1/traces/nonexistent-id", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "does not expose traces from other projects" do
      other_trace = create(:trace, :completed)
      get "/api/v1/traces/#{other_trace.trace_id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
