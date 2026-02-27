require "rails_helper"

RSpec.describe "API V1 Spans", type: :request do
  let(:api_key) { "pls_testkey_spans_#{SecureRandom.hex(4)}" }
  let(:project) { create(:project, settings: { "api_key" => api_key }) }
  let(:headers) { auth_headers(project).merge("Content-Type" => "application/json") }

  # ──────────────────────────────────────────────
  # POST /api/v1/spans
  # ──────────────────────────────────────────────
  describe "POST /api/v1/spans" do
    let(:trace) { create(:trace, project: project) }

    let(:payload) do
      {
        span_id: "span-standalone-001",
        trace_id: trace.trace_id,
        name: "SELECT users",
        kind: "db",
        started_at: 50.milliseconds.ago.iso8601(3),
        duration_ms: 12.5,
        data: { sql: "SELECT * FROM users WHERE id = 1", table: "users" }
      }
    end

    it "creates a span attached to the existing trace and returns 201" do
      expect {
        post "/api/v1/spans", params: payload.to_json, headers: headers
      }.to change(Span, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "returns the span_id and trace_id" do
      post "/api/v1/spans", params: payload.to_json, headers: headers
      body = response.parsed_body
      expect(body["span_id"]).to eq("span-standalone-001")
      expect(body["trace_id"]).to eq(trace.trace_id)
    end

    it "creates a new trace when no matching trace_id exists" do
      payload_no_trace = payload.merge(trace_id: "brand-new-trace-#{SecureRandom.hex(4)}")
      expect {
        post "/api/v1/spans", params: payload_no_trace.to_json, headers: headers
      }.to change(Trace, :count).by(1)
    end

    it "finds a trace by request_id when trace_id is absent" do
      trace_with_request_id = create(:trace, project: project, request_id: "req-abc-001")
      payload_by_request = {
        span_id: "span-req-001",
        request_id: "req-abc-001",
        name: "cache.read",
        kind: "cache",
        started_at: 10.milliseconds.ago.iso8601(3),
        duration_ms: 2.0
      }

      post "/api/v1/spans", params: payload_by_request.to_json, headers: headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["trace_id"]).to eq(trace_with_request_id.trace_id)
    end

    it "returns 401 without authentication" do
      post "/api/v1/spans", params: payload.to_json,
           headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ──────────────────────────────────────────────
  # POST /api/v1/spans/batch
  # ──────────────────────────────────────────────
  describe "POST /api/v1/spans/batch" do
    let(:trace) { create(:trace, project: project) }

    let(:batch_payload) do
      {
        spans: [
          {
            span_id: "batch-span-001",
            trace_id: trace.trace_id,
            name: "SELECT users",
            kind: "db",
            started_at: 40.milliseconds.ago.iso8601(3),
            duration_ms: 8.0
          },
          {
            span_id: "batch-span-002",
            trace_id: trace.trace_id,
            name: "cache.read",
            kind: "cache",
            started_at: 30.milliseconds.ago.iso8601(3),
            duration_ms: 1.5
          }
        ]
      }
    end

    it "creates all spans and returns 201" do
      expect {
        post "/api/v1/spans/batch", params: batch_payload.to_json, headers: headers
      }.to change(Span, :count).by(2)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["count"]).to eq(2)
    end

    it "returns span_id and trace_id for each span" do
      post "/api/v1/spans/batch", params: batch_payload.to_json, headers: headers
      spans = response.parsed_body["spans"]
      expect(spans.map { |s| s["span_id"] }).to contain_exactly("batch-span-001", "batch-span-002")
    end

    it "returns 401 without authentication" do
      post "/api/v1/spans/batch", params: batch_payload.to_json,
           headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
