module Dashboard
  class AlertsController < BaseController
    def index
      @alerts = @project.alerts.includes(:alert_rule).recent.limit(100)
      @firing = @alerts.select(&:firing?)
      @resolved = @alerts.select(&:resolved?)
    end

    def show
      @alert = @project.alerts.includes(:alert_rule, :alert_notifications).find(params[:id])
    end
  end
end
