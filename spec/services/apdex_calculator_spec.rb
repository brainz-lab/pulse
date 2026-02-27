require "rails_helper"

RSpec.describe ApdexCalculator do
  describe ".calculate" do
    let(:project) { create(:project, settings: { "apdex_t" => 0.5 }) }

    context "when there are no traces" do
      it "returns 1.0 (perfect score for empty data)" do
        traces = project.traces.none
        expect(described_class.calculate(traces: traces, threshold: 0.5)).to eq(1.0)
      end
    end

    context "when all traces are satisfied (duration <= T)" do
      it "returns 1.0" do
        create(:trace, :completed, project: project, duration_ms: 400) # <= 500ms
        create(:trace, :completed, project: project, duration_ms: 300)
        traces = project.traces.where(kind: "request")
        expect(described_class.calculate(traces: traces, threshold: 0.5)).to eq(1.0)
      end
    end

    context "when all traces are tolerating (T < duration <= 4T)" do
      it "returns 0.5" do
        create(:trace, :completed, project: project, duration_ms: 600)  # 500 < 600 <= 2000
        create(:trace, :completed, project: project, duration_ms: 1000)
        traces = project.traces.where(kind: "request")
        expect(described_class.calculate(traces: traces, threshold: 0.5)).to eq(0.5)
      end
    end

    context "when all traces are frustrated (duration > 4T)" do
      it "returns 0.0" do
        create(:trace, :completed, project: project, duration_ms: 2500)  # > 2000ms
        create(:trace, :completed, project: project, duration_ms: 3000)
        traces = project.traces.where(kind: "request")
        expect(described_class.calculate(traces: traces, threshold: 0.5)).to eq(0.0)
      end
    end

    context "with a mixed set of traces" do
      it "applies the Apdex formula: (satisfied + tolerating/2) / total" do
        # T = 0.5s (500ms), 4T = 2000ms
        create(:trace, :completed, project: project, duration_ms: 200)   # satisfied
        create(:trace, :completed, project: project, duration_ms: 400)   # satisfied
        create(:trace, :completed, project: project, duration_ms: 800)   # tolerating
        create(:trace, :completed, project: project, duration_ms: 3000)  # frustrated
        traces = project.traces.where(kind: "request")
        # (2 + 1/2) / 4 = 2.5/4 = 0.63
        expect(described_class.calculate(traces: traces, threshold: 0.5)).to eq(0.63)
      end
    end

    context "with a custom threshold" do
      it "respects the provided threshold" do
        create(:trace, :completed, project: project, duration_ms: 800)  # satisfied at T=1.0
        traces = project.traces.where(kind: "request")
        expect(described_class.calculate(traces: traces, threshold: 1.0)).to eq(1.0)
        expect(described_class.calculate(traces: traces, threshold: 0.5)).to eq(0.5) # tolerating at T=0.5
      end
    end
  end
end
