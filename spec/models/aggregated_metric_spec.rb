require "rails_helper"

RSpec.describe AggregatedMetric, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:bucket) }
    it { is_expected.to validate_inclusion_of(:granularity).in_array(described_class::GRANULARITIES) }
  end

  describe "scopes" do
    describe ".for_range" do
      it "returns aggregations within the time range" do
        inside = create(:aggregated_metric, bucket: 30.minutes.ago)
        outside = create(:aggregated_metric, bucket: 3.hours.ago)
        expect(described_class.for_range(1.hour.ago)).to include(inside)
        expect(described_class.for_range(1.hour.ago)).not_to include(outside)
      end
    end

    describe ".by_granularity" do
      it "filters by granularity" do
        hourly = create(:aggregated_metric, granularity: "hour")
        daily = create(:aggregated_metric, :day)
        expect(described_class.by_granularity("hour")).to include(hourly)
        expect(described_class.by_granularity("hour")).not_to include(daily)
      end
    end
  end
end
