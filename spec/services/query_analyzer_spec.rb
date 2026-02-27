require "rails_helper"

RSpec.describe QueryAnalyzer do
  let(:project)  { create(:project) }
  let(:analyzer) { described_class.new(project: project, since: 1.hour.ago) }

  def create_trace_with_db_span(duration_ms:, sql:, table: "users", started_at: 30.minutes.ago)
    trace = create(:trace, :completed, project: project, started_at: started_at)
    create(:span, trace: trace, project: project, kind: "db",
           duration_ms: duration_ms,
           started_at: trace.started_at + 0.01,
           data: { "sql" => sql, "table" => table, "operation" => "SELECT" })
    trace
  end

  describe "#slow_queries" do
    it "returns spans with duration >= threshold ordered by duration desc" do
      create_trace_with_db_span(duration_ms: 50,  sql: "SELECT * FROM users WHERE id = 1")
      create_trace_with_db_span(duration_ms: 200, sql: "SELECT * FROM posts WHERE id = 1")
      create_trace_with_db_span(duration_ms: 500, sql: "SELECT * FROM orders WHERE id = 1")

      results = analyzer.slow_queries(threshold_ms: 100)
      expect(results.length).to eq(2)
      expect(results.first[:duration_ms]).to eq(500)
    end

    it "includes normalized SQL and table info" do
      create_trace_with_db_span(duration_ms: 150, sql: "SELECT * FROM users WHERE id = 42", table: "users")
      result = analyzer.slow_queries(threshold_ms: 100).first
      expect(result[:normalized_sql]).to eq("SELECT * FROM users WHERE id = ?")
      expect(result[:table]).to eq("users")
    end

    it "returns an empty array when no slow queries exist" do
      create_trace_with_db_span(duration_ms: 10, sql: "SELECT * FROM users WHERE id = 1")
      expect(analyzer.slow_queries(threshold_ms: 100)).to be_empty
    end

    it "excludes traces outside the time window" do
      create_trace_with_db_span(duration_ms: 200, sql: "SELECT * FROM users WHERE id = 1",
                                started_at: 2.hours.ago)
      expect(analyzer.slow_queries(threshold_ms: 100)).to be_empty
    end
  end

  describe "#frequent_queries" do
    it "groups queries by fingerprint and counts occurrences" do
      3.times { create_trace_with_db_span(duration_ms: 10, sql: "SELECT * FROM users WHERE id = 1") }
      1.times { create_trace_with_db_span(duration_ms: 10, sql: "SELECT * FROM posts WHERE id = 1") }

      results = analyzer.frequent_queries
      top = results.first
      expect(top[:count]).to eq(3)
    end

    it "calculates average duration per pattern" do
      create_trace_with_db_span(duration_ms: 10, sql: "SELECT * FROM users WHERE id = 1")
      create_trace_with_db_span(duration_ms: 20, sql: "SELECT * FROM users WHERE id = 2")

      results = analyzer.frequent_queries
      top = results.first
      expect(top[:avg_duration_ms]).to be_within(0.1).of(15.0)
    end

    it "returns empty array when no db spans exist" do
      expect(analyzer.frequent_queries).to be_empty
    end
  end

  describe "#summary" do
    context "with db spans" do
      before do
        create_trace_with_db_span(duration_ms: 50,  sql: "SELECT * FROM users WHERE id = 1",  table: "users")
        create_trace_with_db_span(duration_ms: 150, sql: "SELECT * FROM users WHERE id = 2",  table: "users")
        create_trace_with_db_span(duration_ms: 600, sql: "SELECT * FROM orders WHERE id = 1", table: "orders")
      end

      it "returns total query count" do
        expect(analyzer.summary[:total_queries]).to eq(3)
      end

      it "returns slow_count (>= 100ms)" do
        expect(analyzer.summary[:slow_count]).to eq(2)
      end

      it "returns very_slow_count (>= 500ms)" do
        expect(analyzer.summary[:very_slow_count]).to eq(1)
      end

      it "lists unique tables" do
        expect(analyzer.summary[:tables]).to contain_exactly("users", "orders")
      end
    end

    context "without db spans" do
      it "returns all-zero summary" do
        summary = analyzer.summary
        expect(summary[:total_queries]).to eq(0)
        expect(summary[:avg_duration_ms]).to eq(0)
        expect(summary[:tables]).to be_empty
      end
    end
  end

  describe "#table_breakdown" do
    it "returns stats grouped by table name" do
      2.times { create_trace_with_db_span(duration_ms: 10, sql: "SELECT 1", table: "users") }
      1.times { create_trace_with_db_span(duration_ms: 20, sql: "SELECT 1", table: "posts") }

      breakdown = analyzer.table_breakdown
      users_row = breakdown.find { |r| r[:table] == "users" }
      expect(users_row[:count]).to eq(2)
      expect(users_row[:avg_duration_ms]).to be_within(0.1).of(10.0)
    end

    it "sorts by count descending" do
      3.times { create_trace_with_db_span(duration_ms: 5, sql: "SELECT 1", table: "users") }
      1.times { create_trace_with_db_span(duration_ms: 5, sql: "SELECT 1", table: "orders") }

      breakdown = analyzer.table_breakdown
      expect(breakdown.first[:table]).to eq("users")
    end
  end
end
