module Mcp
  module Tools
    class PulseSloStatus < Base
      DESCRIPTION = "List SLO (Service Level Objective) status with current values, error budgets, and burn rates"

      SCHEMA = {
        type: "object",
        properties: {}
      }.freeze

      def call(args)
        unless @project.respond_to?(:service_level_objectives) &&
               ActiveRecord::Base.connection.table_exists?(:service_level_objectives) &&
               ActiveRecord::Base.connection.column_exists?(:service_level_objectives, :project_id)
          return { message: "SLO tracking is not yet available. Deploy the latest version to enable SLOs." }
        end

        slos = @project.service_level_objectives.where(enabled: true)

        if slos.empty?
          return { message: "No SLOs configured. Create SLOs via the dashboard to track service level objectives." }
        end

        {
          slos: slos.map { |slo|
            meeting = case slo.operator
            when "lte" then slo.current_value.present? && slo.current_value <= slo.threshold
            when "gte" then slo.current_value.present? && slo.current_value >= slo.threshold
            else false
            end

            {
              name: slo.name,
              target_metric: slo.target_metric,
              threshold: slo.threshold,
              operator: slo.operator,
              current_value: slo.current_value,
              meeting_target: meeting,
              error_budget_remaining: slo.error_budget_remaining,
              burn_rate: slo.burn_rate,
              window_days: slo.window_days,
              last_calculated_at: slo.last_calculated_at
            }
          },
          total: slos.count,
          meeting: slos.count { |s|
            case s.operator
            when "lte" then s.current_value.present? && s.current_value <= s.threshold
            when "gte" then s.current_value.present? && s.current_value >= s.threshold
            else false
            end
          }
        }
      end
    end
  end
end
