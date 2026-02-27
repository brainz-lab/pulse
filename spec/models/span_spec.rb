require "rails_helper"

RSpec.describe Span, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:trace) }
    it { is_expected.to belong_to(:project) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:span_id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_inclusion_of(:kind).in_array(described_class::KINDS) }
    it { is_expected.to validate_presence_of(:started_at) }
  end

  describe "scopes" do
    describe ".db_spans" do
      it "returns only db kind spans" do
        db = create(:span, kind: "db")
        http = create(:span, :http)
        expect(described_class.db_spans).to include(db)
        expect(described_class.db_spans).not_to include(http)
      end
    end

    describe ".browser_spans" do
      it "returns all browser.* kind spans" do
        browser = create(:span, :browser_lcp)
        db = create(:span, kind: "db")
        expect(described_class.browser_spans).to include(browser)
        expect(described_class.browser_spans).not_to include(db)
      end
    end

    describe ".slow" do
      it "returns spans exceeding the threshold" do
        fast = create(:span, duration_ms: 50)
        slow = create(:span, :slow)
        expect(described_class.slow(200)).to include(slow)
        expect(described_class.slow(200)).not_to include(fast)
      end
    end
  end

  describe "duration calculation" do
    it "calculates duration_ms from ended_at - started_at before save" do
      started = Time.current
      ended = started + 0.123
      span = create(:span, started_at: started, ended_at: ended, duration_ms: nil)
      expect(span.duration_ms).to be_within(1).of(123)
    end

    it "does not overwrite an existing duration_ms" do
      span = create(:span, duration_ms: 99.9)
      expect(span.duration_ms).to eq(99.9)
    end
  end

  describe "#display_name" do
    it "formats db span with operation and table" do
      span = build(:span, kind: "db", data: { "operation" => "SELECT", "table" => "users" })
      expect(span.display_name).to eq("SELECT users")
    end

    it "formats db span without table" do
      span = build(:span, kind: "db", data: { "operation" => "EXEC" })
      expect(span.display_name).to eq("EXEC")
    end

    it "formats http span" do
      span = build(:span, :http)
      expect(span.display_name).to eq("GET https://api.example.com/users")
    end

    it "formats cache hit span" do
      span = build(:span, :cache)
      expect(span.display_name).to eq("Cache HIT: users/1")
    end

    it "formats cache miss span" do
      span = build(:span, kind: "cache", data: { "hit" => false, "key" => "missing" })
      expect(span.display_name).to eq("Cache MISS: missing")
    end

    it "formats browser.lcp span" do
      span = build(:span, :browser_lcp, duration_ms: 1200.0)
      expect(span.display_name).to eq("LCP: 1200ms (good)")
    end

    it "returns name for unrecognized kind" do
      span = build(:span, kind: "custom", name: "my custom span")
      expect(span.display_name).to eq("my custom span")
    end
  end
end
