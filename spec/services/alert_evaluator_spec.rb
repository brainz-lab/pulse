require "rails_helper"

RSpec.describe AlertEvaluator do
  let(:project) { create(:project, settings: { "apdex_t" => 0.5 }) }
  let(:evaluator) { described_class.new(project: project) }

  before do
    allow(SendAlertNotificationsJob).to receive(:perform_later)
    allow(AlertsChannel).to receive(:broadcast_to)
  end

  describe "#evaluate_all!" do
    it "evaluates all enabled alert rules for the project" do
      rule1 = create(:alert_rule, project: project, enabled: true)
      rule2 = create(:alert_rule, project: project, enabled: true)
      create(:alert_rule, project: project, :disabled)

      expect(evaluator).to receive(:evaluate_rule!).with(rule1)
      expect(evaluator).to receive(:evaluate_rule!).with(rule2)
      evaluator.evaluate_all!
    end
  end

  describe "#evaluate_rule!" do
    context "error_rate metric" do
      let(:rule) do
        create(:alert_rule, project: project,
               metric_type: "error_rate", operator: "gt", threshold: 5.0,
               window_minutes: 5, status: "ok")
      end

      it "triggers an alert when error rate exceeds threshold" do
        # Create 10 traces, 2 with errors = 20% error rate > 5%
        8.times { create(:trace, :completed, project: project, started_at: 2.minutes.ago) }
        2.times { create(:trace, :error, project: project, started_at: 2.minutes.ago) }

        expect { evaluator.evaluate_rule!(rule) }.to change(Alert, :count).by(1)
        expect(rule.reload.status).to eq("alerting")
      end

      it "resolves an alerting rule when error rate drops below threshold" do
        rule.update!(status: "alerting", last_triggered_at: 20.minutes.ago)
        # All traces succeed — error rate = 0%
        5.times { create(:trace, :completed, project: project, started_at: 2.minutes.ago) }

        evaluator.evaluate_rule!(rule)

        expect(rule.reload.status).to eq("ok")
      end

      it "does nothing when there are no traces in the window" do
        expect { evaluator.evaluate_rule!(rule) }.not_to change(Alert, :count)
      end
    end

    context "apdex metric" do
      let(:rule) do
        create(:alert_rule, project: project,
               metric_type: "apdex", operator: "lt", threshold: 0.7,
               window_minutes: 5, status: "ok")
      end

      it "triggers when Apdex score falls below threshold" do
        # All frustrated traces → Apdex = 0
        4.times { create(:trace, :completed, project: project, duration_ms: 5000, started_at: 2.minutes.ago) }

        expect { evaluator.evaluate_rule!(rule) }.to change(Alert, :count).by(1)
      end
    end

    context "throughput metric" do
      let(:rule) do
        create(:alert_rule, project: project,
               metric_type: "throughput", operator: "lt", threshold: 10.0,
               window_minutes: 1, status: "ok")
      end

      it "triggers when throughput drops below threshold" do
        # Only 2 requests in a 1-minute window → ~2 RPM < 10 RPM
        2.times { create(:trace, :completed, project: project, started_at: 30.seconds.ago) }

        expect { evaluator.evaluate_rule!(rule) }.to change(Alert, :count).by(1)
      end
    end

    context "custom metric" do
      let(:rule) do
        create(:alert_rule, :custom_metric, project: project,
               operator: "gt", threshold: 5.0,
               aggregation: "avg", window_minutes: 5, status: "ok")
      end

      it "triggers when custom metric average exceeds threshold" do
        metric = create(:metric, project: project, name: "orders.failed")
        3.times { create(:metric_point, project: project, metric: metric, value: 10.0, timestamp: 2.minutes.ago) }

        expect { evaluator.evaluate_rule!(rule) }.to change(Alert, :count).by(1)
      end
    end

    it "updates last_checked_at on the rule" do
      rule = create(:alert_rule, project: project, metric_type: "error_rate",
                    operator: "gt", threshold: 5.0, window_minutes: 5)
      freeze_time do
        evaluator.evaluate_rule!(rule)
        expect(rule.reload.last_checked_at).to be_within(1.second).of(Time.current)
      end
    end

    it "creates pending alert_notifications for all enabled channels when alert fires" do
      rule = create(:alert_rule, project: project,
                    metric_type: "error_rate", operator: "gt", threshold: 5.0,
                    window_minutes: 5, status: "ok")
      channel = create(:notification_channel, project: project, enabled: true)
      rule.notification_channels << channel

      5.times { create(:trace, :error, project: project, started_at: 2.minutes.ago) }

      evaluator.evaluate_rule!(rule)

      alert = Alert.last
      expect(alert.alert_notifications.count).to eq(1)
      expect(alert.alert_notifications.first.notification_channel).to eq(channel)
      expect(SendAlertNotificationsJob).to have_received(:perform_later).with(alert.id)
    end
  end
end
