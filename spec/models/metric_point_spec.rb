require "rails_helper"

RSpec.describe MetricPoint, type: :model, timescaledb: true do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:metric) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:timestamp) }
    it { is_expected.to validate_presence_of(:value) }
  end

  it "persists a valid metric point" do
    point = create(:metric_point)
    expect(point).to be_persisted
    expect(point.value).to eq(42.0)
  end
end
