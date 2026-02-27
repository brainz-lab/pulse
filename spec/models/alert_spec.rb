require "rails_helper"

RSpec.describe Alert, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:alert_rule) }
    it { is_expected.to have_many(:alert_notifications).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(described_class::STATUSES) }
    it { is_expected.to validate_presence_of(:severity) }
    it { is_expected.to validate_presence_of(:metric_type) }
    it { is_expected.to validate_presence_of(:operator) }
    it { is_expected.to validate_presence_of(:threshold) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_presence_of(:triggered_at) }
  end

  describe "scopes" do
    describe ".firing" do
      it "returns only firing alerts" do
        firing = create(:alert, status: "firing")
        resolved = create(:alert, :resolved)
        expect(described_class.firing).to include(firing)
        expect(described_class.firing).not_to include(resolved)
      end
    end

    describe ".resolved" do
      it "returns only resolved alerts" do
        firing = create(:alert, status: "firing")
        resolved = create(:alert, :resolved)
        expect(described_class.resolved).to include(resolved)
        expect(described_class.resolved).not_to include(firing)
      end
    end

    describe ".critical" do
      it "returns only critical severity alerts" do
        critical = create(:alert, :critical)
        warning = create(:alert, severity: "warning")
        expect(described_class.critical).to include(critical)
        expect(described_class.critical).not_to include(warning)
      end
    end
  end

  describe "#firing?" do
    it "returns true when status is firing" do
      expect(build(:alert, status: "firing").firing?).to be true
    end

    it "returns false when status is resolved" do
      expect(build(:alert, :resolved).firing?).to be false
    end
  end

  describe "#resolved?" do
    it "returns true when status is resolved" do
      expect(build(:alert, :resolved).resolved?).to be true
    end

    it "returns false when status is firing" do
      expect(build(:alert, status: "firing").resolved?).to be false
    end
  end

  describe "#duration" do
    it "returns nil when resolved_at is not set" do
      alert = build(:alert, resolved_at: nil)
      expect(alert.duration).to be_nil
    end

    it "returns the elapsed time in seconds" do
      triggered = 10.minutes.ago
      resolved = Time.current
      alert = build(:alert, triggered_at: triggered, resolved_at: resolved)
      expect(alert.duration).to be_within(1).of(600)
    end
  end

  describe "#duration_text" do
    it "returns 'ongoing' for a firing alert" do
      expect(build(:alert, status: "firing").duration_text).to eq("ongoing")
    end

    it "formats seconds when duration < 60" do
      alert = build(:alert, :resolved, triggered_at: 45.seconds.ago, resolved_at: Time.current)
      expect(alert.duration_text).to match(/\d+s/)
    end

    it "formats minutes when duration < 3600" do
      alert = build(:alert, :resolved, triggered_at: 5.minutes.ago, resolved_at: Time.current)
      expect(alert.duration_text).to match(/\d+m/)
    end

    it "formats hours and minutes when duration >= 3600" do
      alert = build(:alert, :resolved, triggered_at: 2.hours.ago, resolved_at: Time.current)
      expect(alert.duration_text).to match(/\d+h \d+m/)
    end
  end
end
