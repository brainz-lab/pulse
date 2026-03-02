require "rails_helper"

RSpec.describe NPlusOneDetector do
  let(:project)  { create(:project) }
  let(:detector) { described_class.new(project: project, since: 1.hour.ago) }

  def create_db_span(trace, sql:, table: "users", count: 1)
    count.times do |i|
      create(:span, trace: trace, project: project, kind: "db",
             data: { "sql" => sql, "table" => table, "operation" => "SELECT" },
             duration_ms: 5.0)
    end
  end

  describe "#analyze_trace" do
    context "when there are fewer than MINIMUM_REPEAT_COUNT db spans" do
      it "returns an empty array" do
        trace = create(:trace, :completed, project: project)
        create_db_span(trace, sql: "SELECT * FROM users WHERE id = 1", count: 2)
        expect(detector.analyze_trace(trace)).to be_empty
      end
    end

    context "when there are repeated identical queries (N+1 pattern)" do
      it "detects the pattern and returns it" do
        trace = create(:trace, :completed, project: project)
        create_db_span(trace, sql: "SELECT * FROM users WHERE id = 1", count: 5)

        patterns = detector.analyze_trace(trace)
        expect(patterns).not_to be_empty
        expect(patterns.first[:count]).to eq(5)
        expect(patterns.first[:table]).to eq("users")
      end

      it "includes normalized SQL and fingerprint" do
        trace = create(:trace, :completed, project: project)
        create_db_span(trace, sql: "SELECT * FROM posts WHERE user_id = 42", count: 4)

        pattern = detector.analyze_trace(trace).first
        expect(pattern[:normalized_sql]).to eq("SELECT * FROM posts WHERE user_id = ?")
        expect(pattern[:fingerprint]).not_to be_nil
      end

      it "calculates total and average duration" do
        trace = create(:trace, :completed, project: project)
        create_db_span(trace, sql: "SELECT * FROM users WHERE id = 1", count: 4) # 4 x 5ms = 20ms

        pattern = detector.analyze_trace(trace).first
        expect(pattern[:total_duration_ms]).to be_within(1).of(20)
        expect(pattern[:avg_duration_ms]).to be_within(0.1).of(5.0)
      end
    end

    context "when queries are all structurally different" do
      it "returns an empty array" do
        trace = create(:trace, :completed, project: project)
        [ "users", "posts", "comments" ].each do |table|
          create(:span, trace: trace, project: project, kind: "db",
                 data: { "sql" => "SELECT * FROM #{table} WHERE id = 1", "table" => table },
                 duration_ms: 5.0)
        end
        expect(detector.analyze_trace(trace)).to be_empty
      end
    end

    it "sorts patterns by count descending" do
      trace = create(:trace, :completed, project: project)
      create_db_span(trace, sql: "SELECT * FROM posts WHERE id = 1", table: "posts", count: 3)
      create_db_span(trace, sql: "SELECT * FROM users WHERE id = 1", table: "users", count: 6)

      patterns = detector.analyze_trace(trace)
      expect(patterns.first[:count]).to be >= patterns.last[:count]
    end
  end

  describe "#find_affected_traces" do
    it "returns traces with N+1 patterns and potential savings" do
      trace = create(:trace, :completed, project: project, started_at: 30.minutes.ago)
      create_db_span(trace, sql: "SELECT * FROM users WHERE id = 1", count: 5)
      trace.update!(span_count: 5)

      results = detector.find_affected_traces
      expect(results).not_to be_empty
      expect(results.first[:trace]).to eq(trace)
      expect(results.first[:potential_savings_ms]).to be > 0
    end

    it "excludes traces with insufficient span counts" do
      trace = create(:trace, :completed, project: project, started_at: 30.minutes.ago)
      create_db_span(trace, sql: "SELECT * FROM users WHERE id = 1", count: 2)
      trace.update!(span_count: 2)

      expect(detector.find_affected_traces).to be_empty
    end
  end
end
