require "rails_helper"

RSpec.describe Project, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:traces).dependent(:destroy) }
    it { is_expected.to have_many(:spans).dependent(:destroy) }
    it { is_expected.to have_many(:metrics).dependent(:destroy) }
    it { is_expected.to have_many(:metric_points).dependent(:destroy) }
    it { is_expected.to have_many(:aggregated_metrics).dependent(:destroy) }
    it { is_expected.to have_many(:notification_channels).dependent(:destroy) }
    it { is_expected.to have_many(:alert_rules).dependent(:destroy) }
    it { is_expected.to have_many(:alerts).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:platform_project_id) }
    it { is_expected.to validate_uniqueness_of(:platform_project_id) }
  end

  describe "scopes" do
    describe ".active" do
      it "returns projects without archived_at" do
        active = create(:project)
        archived = create(:project, :archived)
        expect(described_class.active).to include(active)
        expect(described_class.active).not_to include(archived)
      end
    end

    describe ".archived" do
      it "returns projects with archived_at set" do
        active = create(:project)
        archived = create(:project, :archived)
        expect(described_class.archived).to include(archived)
        expect(described_class.archived).not_to include(active)
      end
    end
  end

  describe "#apdex_t" do
    it "returns 0.5 by default when no settings" do
      project = build(:project, settings: {})
      expect(project.apdex_t).to eq(0.5)
    end

    it "returns the configured value from settings" do
      project = build(:project, :with_apdex_t)
      expect(project.apdex_t).to eq(1.0)
    end

    it "returns 0.5 when settings is nil" do
      project = build(:project, settings: nil)
      expect(project.apdex_t).to eq(0.5)
    end
  end

  describe ".find_or_create_for_platform!" do
    it "creates a new project when none exists" do
      platform_id = SecureRandom.uuid
      expect {
        described_class.find_or_create_for_platform!(platform_project_id: platform_id, name: "My App")
      }.to change(described_class, :count).by(1)
    end

    it "returns the existing project when one already exists" do
      project = create(:project)
      result = described_class.find_or_create_for_platform!(platform_project_id: project.platform_project_id)
      expect(result).to eq(project)
    end

    it "sets name and environment on creation" do
      platform_id = SecureRandom.uuid
      project = described_class.find_or_create_for_platform!(
        platform_project_id: platform_id,
        name: "My App",
        environment: "staging"
      )
      expect(project.name).to eq("My App")
      expect(project.environment).to eq("staging")
    end

    it "does not update name on subsequent calls" do
      project = create(:project, name: "Original")
      result = described_class.find_or_create_for_platform!(
        platform_project_id: project.platform_project_id,
        name: "New Name"
      )
      expect(result.name).to eq("Original")
    end
  end
end
