require "rails_helper"

RSpec.describe Metric, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to have_many(:points).class_name("MetricPoint").dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_inclusion_of(:kind).in_array(described_class::KINDS) }

    it "validates name uniqueness scoped to project" do
      project = create(:project)
      create(:metric, project: project, name: "cpu.usage")
      duplicate = build(:metric, project: project, name: "cpu.usage")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "allows same name in different projects" do
      create(:metric, name: "cpu.usage")
      other = build(:metric, name: "cpu.usage")
      expect(other).to be_valid
    end
  end

  describe "#record!" do
    it "creates a metric point with the given value" do
      metric = create(:metric)
      expect { metric.record!(42.0) }.to change(MetricPoint, :count).by(1)
      expect(metric.points.last.value).to eq(42.0)
    end

    it "merges provided tags with metric default tags" do
      metric = create(:metric, tags: { "env" => "production" })
      metric.record!(10.0, tags: { "host" => "web-1" })
      point = metric.points.last
      expect(point.tags).to include("env" => "production", "host" => "web-1")
    end

    it "uses the provided timestamp" do
      metric = create(:metric)
      ts = 1.hour.ago
      metric.record!(5.0, timestamp: ts)
      expect(metric.points.last.timestamp).to be_within(1.second).of(ts)
    end
  end
end
