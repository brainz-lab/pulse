require "rails_helper"

RSpec.describe "API V1 Projects", type: :request do
  let(:master_key) { "test_master_key_pulse" }
  let(:headers) { master_key_headers(master_key).merge("Content-Type" => "application/json") }

  before { stub_const("ENV", ENV.to_h.merge("PULSE_MASTER_KEY" => master_key)) }

  # ──────────────────────────────────────────────
  # POST /api/v1/projects/provision
  # ──────────────────────────────────────────────
  describe "POST /api/v1/projects/provision" do
    context "with a platform_project_id" do
      let(:payload) do
        { platform_project_id: "plat-proj-abc", name: "My App", environment: "production" }
      end

      it "creates a new project and returns 200" do
        expect {
          post "/api/v1/projects/provision", params: payload.to_json, headers: headers
        }.to change(Project, :count).by(1)

        expect(response).to have_http_status(:ok)
      end

      it "returns the project with generated api_key and ingest_key" do
        post "/api/v1/projects/provision", params: payload.to_json, headers: headers
        body = response.parsed_body
        expect(body["platform_project_id"]).to eq("plat-proj-abc")
        expect(body["api_key"]).to start_with("pls_api_")
        expect(body["ingest_key"]).to start_with("pls_ingest_")
      end

      it "is idempotent — does not duplicate on repeated calls" do
        post "/api/v1/projects/provision", params: payload.to_json, headers: headers
        expect {
          post "/api/v1/projects/provision", params: payload.to_json, headers: headers
        }.not_to change(Project, :count)
      end
    end

    context "with a name only (standalone mode)" do
      it "creates a project with a generated platform_project_id" do
        post "/api/v1/projects/provision",
             params: { name: "Standalone App" }.to_json, headers: headers
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["platform_project_id"]).to start_with("pls_")
      end
    end

    context "without platform_project_id or name" do
      it "returns 400 bad_request" do
        post "/api/v1/projects/provision", params: {}.to_json, headers: headers
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "without master key" do
      it "returns 401" do
        post "/api/v1/projects/provision",
             params: { platform_project_id: "proj-x" }.to_json,
             headers: { "Content-Type" => "application/json" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with incorrect master key" do
      it "returns 401" do
        post "/api/v1/projects/provision",
             params: { platform_project_id: "proj-x" }.to_json,
             headers: master_key_headers("wrong_key").merge("Content-Type" => "application/json")
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ──────────────────────────────────────────────
  # GET /api/v1/projects/lookup
  # ──────────────────────────────────────────────
  describe "GET /api/v1/projects/lookup" do
    let!(:project) do
      create(:project, name: "Lookup App",
             platform_project_id: "plat-lookup-123",
             settings: { "api_key" => "pls_api_abc", "ingest_key" => "pls_ingest_abc" })
    end

    it "finds a project by platform_project_id" do
      get "/api/v1/projects/lookup",
          params: { platform_project_id: "plat-lookup-123" }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["name"]).to eq("Lookup App")
    end

    it "finds a project by name" do
      get "/api/v1/projects/lookup",
          params: { name: "Lookup App" }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["platform_project_id"]).to eq("plat-lookup-123")
    end

    it "returns 404 when not found" do
      get "/api/v1/projects/lookup",
          params: { platform_project_id: "nonexistent" }, headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without master key" do
      get "/api/v1/projects/lookup",
          params: { platform_project_id: "plat-lookup-123" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
