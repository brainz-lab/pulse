module Mcp
  module Tools
    class PulseDeployImpact < Base
      DESCRIPTION = "Analyze the performance impact of a deployment by comparing metrics 1 hour before and after"

      SCHEMA = {
        type: "object",
        properties: {
          deploy_id: { type: "string", description: "Optional: specific deploy ID. Defaults to most recent deploy." }
        }
      }.freeze

      def call(args)
        unless @project.respond_to?(:deploys) &&
               ActiveRecord::Base.connection.table_exists?(:deploys)
          return { message: "Deploy tracking is not yet available. Deploy the latest version to enable deploy markers." }
        end

        deploy = if args[:deploy_id].present?
          @project.deploys.find_by(id: args[:deploy_id])
        else
          @project.deploys.recent.first
        end

        unless deploy
          return { message: "No deploys found. Record deploys via the API to track deployment impact." }
        end

        before_metrics = compute_metrics(deploy.deployed_at - 1.hour, deploy.deployed_at)
        after_metrics = compute_metrics(deploy.deployed_at, deploy.deployed_at + 1.hour)

        deltas = {}
        before_metrics.each do |key, val_before|
          val_after = after_metrics[key]
          next unless val_before && val_after && val_before != 0
          deltas[key] = {
            before: val_before,
            after: val_after,
            change_pct: ((val_after - val_before).to_f / val_before * 100).round(2)
          }
        end

        {
          deploy: {
            id: deploy.id,
            version: deploy.version,
            commit_sha: deploy.commit_sha,
            deployed_by: deploy.deployed_by,
            deployed_at: deploy.deployed_at
          },
          before_window: "#{deploy.deployed_at - 1.hour} to #{deploy.deployed_at}",
          after_window: "#{deploy.deployed_at} to #{deploy.deployed_at + 1.hour}",
          metrics: deltas
        }
      end

      private

      def compute_metrics(from, to)
        scope = @project.traces.where(started_at: from..to).where(kind: "request")
        total = scope.count
        return {} if total == 0

        stats = scope.where.not(duration_ms: nil).pick(
          Arel.sql("AVG(duration_ms)"),
          Arel.sql("PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms)"),
          Arel.sql("PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms)")
        )

        error_count = scope.where(error: true).count
        {
          throughput: total,
          avg_duration: stats[0]&.round(2),
          p95: stats[1]&.round(2),
          p99: stats[2]&.round(2),
          error_rate: (error_count.to_f / total * 100).round(2)
        }
      end
    end
  end
end
