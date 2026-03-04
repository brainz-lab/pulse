# frozen_string_literal: true

module Dashboard
  class DeploysController < BaseController
    def index
      @deploys = current_project.deploys.recent.limit(50)
      @deploy_impacts = @deploys.map { |deploy| [deploy.id, compute_impact(deploy)] }.to_h
    end

    def show
      @deploy = current_project.deploys.find(params[:id])
      @impact = compute_impact(@deploy)
    end

    private

    def compute_impact(deploy)
      window = 1.hour
      before_scope = current_project.traces.requests
        .where(started_at: (deploy.deployed_at - window)...deploy.deployed_at)
      after_scope = current_project.traces.requests
        .where(started_at: deploy.deployed_at..(deploy.deployed_at + window))

      before_stats = compute_stats(before_scope)
      after_stats = compute_stats(after_scope)

      return { status: :no_data } if before_stats[:count] == 0 && after_stats[:count] == 0

      deltas = {}
      [:avg_duration, :error_rate, :p95_duration].each do |metric|
        prev = before_stats[metric].to_f
        curr = after_stats[metric].to_f
        deltas[metric] = prev > 0 ? ((curr - prev) / prev * 100).round(1) : 0
      end

      status = if deltas[:error_rate] > 10 || deltas[:p95_duration] > 20
                 :degraded
               elsif deltas[:error_rate] < -5 || deltas[:p95_duration] < -10
                 :improved
               else
                 :neutral
               end

      { before: before_stats, after: after_stats, deltas: deltas, status: status }
    end

    def compute_stats(scope)
      count = scope.count
      return { count: 0, avg_duration: 0, error_rate: 0, p95_duration: 0 } if count == 0

      stats = scope.where.not(duration_ms: nil).pick(
        Arel.sql("AVG(duration_ms)"),
        Arel.sql("PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms)")
      )

      error_count = scope.where(error: true).count

      {
        count: count,
        avg_duration: stats&.first&.round(1) || 0,
        p95_duration: stats&.last&.round(1) || 0,
        error_rate: (error_count.to_f / count * 100).round(2)
      }
    end
  end
end
