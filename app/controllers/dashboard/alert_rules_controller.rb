module Dashboard
  class AlertRulesController < BaseController
    before_action :set_alert_rule, only: [ :show, :update, :destroy ]

    def index
      @alert_rules = @project.alert_rules.includes(:notification_channels).order(:name)
    end

    def show
      @recent_alerts = @alert_rule.alerts.recent.limit(10)
    end

    def new
      @alert_rule = @project.alert_rules.build(
        operator: "gt",
        aggregation: "avg",
        window_minutes: 5,
        cooldown_minutes: 60,
        severity: "warning"
      )
      @notification_channels = @project.notification_channels.enabled
    end

    def create
      @alert_rule = @project.alert_rules.build(alert_rule_params)

      if @alert_rule.save
        update_channels
        AlertsChannel.broadcast_alert_rule_created(@project, @alert_rule)
        redirect_to dashboard_alert_rules_path, notice: "Alert rule created."
      else
        @notification_channels = @project.notification_channels.enabled
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @alert_rule.update(alert_rule_params)
        update_channels
        AlertsChannel.broadcast_alert_rule_updated(@project, @alert_rule)
        redirect_to dashboard_alert_rule_path(@alert_rule), notice: "Alert rule updated."
      else
        @notification_channels = @project.notification_channels.enabled
        @recent_alerts = @alert_rule.alerts.recent.limit(10)
        render :show, status: :unprocessable_entity
      end
    end

    def destroy
      alert_rule_id = @alert_rule.id
      @alert_rule.destroy
      AlertsChannel.broadcast_alert_rule_deleted(@project, alert_rule_id)
      redirect_to dashboard_alert_rules_path, notice: "Alert rule deleted."
    end

    private

    def set_alert_rule
      @alert_rule = @project.alert_rules.find(params[:id])
      @notification_channels = @project.notification_channels.enabled
    end

    def alert_rule_params
      params.require(:alert_rule).permit(
        :name, :description, :enabled,
        :metric_type, :metric_name,
        :operator, :threshold, :aggregation,
        :window_minutes, :endpoint, :environment,
        :cooldown_minutes, :severity
      )
    end

    def update_channels
      channel_ids = params[:alert_rule][:notification_channel_ids] || []
      @alert_rule.notification_channel_ids = channel_ids.reject(&:blank?)
    end
  end
end
