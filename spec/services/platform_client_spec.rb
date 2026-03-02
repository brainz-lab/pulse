require "rails_helper"

RSpec.describe PlatformClient do
  let(:platform_url) { "https://platform.brainzlab.ai" }
  let(:validate_url) { "#{platform_url}/api/v1/keys/validate" }

  before { Rails.cache.clear }

  describe ".validate_key" do
    context "with a blank key" do
      it "returns an invalid result without making an HTTP call" do
        result = described_class.validate_key("")
        expect(result.valid?).to be false
        expect(result.error).to eq("Key required")
      end
    end

    context "when Platform returns a valid key" do
      let(:response_body) do
        {
          valid: true,
          project_id: "proj-123",
          project_slug: "my-app",
          organization_id: "org-456",
          environment: "production",
          plan: "pro",
          scopes: [ "read", "write" ]
        }.to_json
      end

      before do
        stub_request(:post, validate_url)
          .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
      end

      it "returns a valid ValidationResult" do
        result = described_class.validate_key("sk_live_abc123")
        expect(result.valid?).to be true
        expect(result.project_id).to eq("proj-123")
        expect(result.environment).to eq("production")
      end

      it "caches the result for subsequent calls" do
        described_class.validate_key("sk_live_abc123")
        described_class.validate_key("sk_live_abc123")
        expect(WebMock).to have_requested(:post, validate_url).once
      end
    end

    context "when Platform returns an invalid key" do
      before do
        stub_request(:post, validate_url)
          .to_return(status: 401, body: '{"error":"Invalid key"}',
                     headers: { "Content-Type" => "application/json" })
      end

      it "returns an invalid ValidationResult" do
        result = described_class.validate_key("sk_live_invalid")
        expect(result.valid?).to be false
      end
    end

    context "when Platform times out" do
      before { stub_request(:post, validate_url).to_timeout }

      it "returns an invalid result with a timeout error" do
        result = described_class.validate_key("sk_live_abc123")
        expect(result.valid?).to be false
        expect(result.error).to include("timeout")
      end
    end
  end

  describe ".find_or_create_project" do
    let(:valid_result) do
      described_class::ValidationResult.new(
        valid: true,
        project_id: "proj-abc",
        project_slug: "my-app",
        environment: "production"
      )
    end

    context "when the project does not exist" do
      it "creates a new project" do
        expect {
          described_class.find_or_create_project(valid_result, "sk_live_abc")
        }.to change(Project, :count).by(1)
      end

      it "assigns the correct attributes" do
        project = described_class.find_or_create_project(valid_result, "sk_live_abc")
        expect(project.platform_project_id).to eq("proj-abc")
        expect(project.environment).to eq("production")
        expect(project.settings["platform_api_key"]).to eq("sk_live_abc")
      end
    end

    context "when the project already exists" do
      let!(:existing_project) do
        create(:project, platform_project_id: "proj-abc", settings: { "platform_api_key" => "sk_live_old" })
      end

      it "returns the existing project without creating a new one" do
        expect {
          described_class.find_or_create_project(valid_result, "sk_live_old")
        }.not_to change(Project, :count)
      end

      it "updates the cached platform_api_key when it changes" do
        described_class.find_or_create_project(valid_result, "sk_live_new")
        expect(existing_project.reload.settings["platform_api_key"]).to eq("sk_live_new")
      end
    end

    context "with an invalid ValidationResult" do
      let(:invalid_result) { described_class::ValidationResult.new(valid: false, error: "Invalid key") }

      it "returns nil" do
        expect(described_class.find_or_create_project(invalid_result, "bad_key")).to be_nil
      end
    end
  end

  describe "ValidationResult" do
    it "#valid? returns true when valid is true" do
      result = described_class::ValidationResult.new(valid: true)
      expect(result.valid?).to be true
    end

    it "#valid? returns false when valid is false or nil" do
      expect(described_class::ValidationResult.new(valid: false).valid?).to be false
      expect(described_class::ValidationResult.new({}).valid?).to be false
    end

    it "defaults scopes to empty array" do
      result = described_class::ValidationResult.new(valid: true)
      expect(result.scopes).to eq([])
    end
  end
end
