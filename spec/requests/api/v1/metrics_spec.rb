require "rails_helper"

RSpec.describe "API V1 Metrics", type: :request do
  let(:api_key) { "pls_testkey_metrics_#{SecureRandom.hex(4)}" }
  let(:project) { create(:project, settings: { "api_key" => api_key }) }
  let(:headers) { auth_headers(project).merge("Content-Type" => "application/json") }

  # ──────────────────────────────────────────────
  # POST /api/v1/metrics
  # ──────────────────────────────────────────────
  describe "POST /api/v1/metrics" do
    let(:payload) { { name: "cpu.usage", kind: "gauge", value: 72.5 } }

    it "creates a metric and records a point, returning 201" do
      expect {
        post "/api/v1/metrics", params: payload.to_json, headers: headers
      }.to change(MetricPoint, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["metric_id"]).not_to be_nil
    end

    it "reuses an existing metric on subsequent calls" do
      post "/api/v1/metrics", params: payload.to_json, headers: headers
      expect {
        post "/api/v1/metrics", params: payload.to_json, headers: headers
      }.to change(MetricPoint, :count).by(1)
                                      .and not_change(Metric, :count)
    end

    it "records the provided value" do
      post "/api/v1/metrics", params: payload.to_json, headers: headers
      expect(MetricPoint.last.value).to eq(72.5)
    end

    it "returns 401 without authentication" do
      post "/api/v1/metrics", params: payload.to_json,
           headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ──────────────────────────────────────────────
  # POST /api/v1/metrics/batch
  # ──────────────────────────────────────────────
  describe "POST /api/v1/metrics/batch" do
    let(:batch_payload) do
      {
        metrics: [
          { name: "cpu.usage",    kind: "gauge",   value: 65.0 },
          { name: "memory.usage", kind: "gauge",   value: 80.0 },
          { name: "req.count",    kind: "counter",  value: 1.0  }
        ]
      }
    end

    it "records all metric points and returns 201" do
      expect {
        post "/api/v1/metrics/batch", params: batch_payload.to_json, headers: headers
      }.to change(MetricPoint, :count).by(3)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["processed"]).to eq(3)
    end

    it "returns 401 without authentication" do
      post "/api/v1/metrics/batch", params: batch_payload.to_json,
           headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ──────────────────────────────────────────────
  # GET /api/v1/metrics
  # ──────────────────────────────────────────────
  describe "GET /api/v1/metrics" do
    before do
      create(:metric, project: project, name: "cpu.usage")
      create(:metric, project: project, name: "memory.usage")
    end

    it "returns all metrics for the project" do
      get "/api/v1/metrics", headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["metrics"].length).to eq(2)
    end

    it "does not return metrics from other projects" do
      create(:metric, name: "other.metric")
      get "/api/v1/metrics", headers: headers
      expect(response.parsed_body["metrics"].length).to eq(2)
    end

    it "returns 401 without authentication" do
      get "/api/v1/metrics"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ──────────────────────────────────────────────
  # GET /api/v1/metrics/:name/stats
  # ──────────────────────────────────────────────
  describe "GET /api/v1/metrics/:name/stats" do
    let(:metric) { create(:metric, project: project, name: "cpu.usage") }

    before do
      create(:metric_point, project: project, metric: metric,
             value: 50.0, timestamp: 30.minutes.ago)
      create(:metric_point, project: project, metric: metric,
             value: 70.0, timestamp: 10.minutes.ago)
    end

    it "returns stats for the named metric" do
      get "/api/v1/metrics/cpu.usage/stats", headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["stats"]).to be_an(Array)
    end

    it "returns 404 for an unknown metric name" do
      get "/api/v1/metrics/nonexistent/stats", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ──────────────────────────────────────────────
  # GET /api/v1/overview
  # ──────────────────────────────────────────────
  describe "GET /api/v1/overview" do
    before do
      create(:trace, :completed, project: project,
             kind: "request", started_at: 30.minutes.ago, duration_ms: 250)
      create(:trace, :error, project: project,
             kind: "request", started_at: 20.minutes.ago, duration_ms: 500)
    end

    it "returns the project overview metrics" do
      get "/api/v1/overview", headers: headers
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to include("apdex", "throughput", "error_rate", "avg_duration")
    end

    it "includes an error_count" do
      get "/api/v1/overview", headers: headers
      expect(response.parsed_body["error_count"]).to eq(1)
    end

    it "respects the since param" do
      get "/api/v1/overview", params: { since: 5.minutes.ago.iso8601 }, headers: headers
      # Both traces are older than 5 minutes ago → throughput should be 0
      expect(response.parsed_body["throughput"]).to eq(0)
    end

    it "returns 401 without authentication" do
      get "/api/v1/overview"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
