module Dashboard
  class SlosController < BaseController
    before_action :set_slo, only: [:show, :destroy]

    def index
      @slos = current_project.service_level_objectives.order(:name)
      @slos.where("last_calculated_at IS NULL OR last_calculated_at < ?", 5.minutes.ago).find_each do |slo|
        SloCalculator.new(slo: slo).calculate!
      end
      @slos.reload
    end

    def show
      SloCalculator.new(slo: @slo).calculate!
      @slo.reload
      @sli_data = compute_sli_timeseries(@slo)
    end

    def new
      @slo = current_project.service_level_objectives.new(
        window_days: 30,
        operator: "lte",
        target_metric: "error_rate"
      )
    end

    def create
      @slo = current_project.service_level_objectives.new(slo_params)
      if @slo.save
        SloCalculator.new(slo: @slo).calculate!
        redirect_to dashboard_slo_path(@slo), notice: "SLO created"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      @slo.destroy
      redirect_to dashboard_slos_path, notice: "SLO deleted"
    end

    private

    def set_slo
      @slo = current_project.service_level_objectives.find(params[:id])
    end

    def slo_params
      params.require(:service_level_objective).permit(
        :name, :description, :target_metric, :operator,
        :threshold, :window_days, :endpoint, :enabled
      )
    end

    def compute_sli_timeseries(slo)
      lookback = [slo.window_days, 7].min.days
      since = lookback.ago
      scope = current_project.traces.where("started_at >= ?", since).where(kind: "request")
      scope = scope.where(name: slo.endpoint) if slo.endpoint.present?

      case slo.target_metric
      when "error_rate"
        scope.group("date_trunc('hour', started_at)")
          .select("date_trunc('hour', started_at) as bucket, COUNT(*) as total, SUM(CASE WHEN error THEN 1 ELSE 0 END) as errors")
          .map { |r| { x: r.bucket.iso8601, y: r.total > 0 ? (r.errors.to_f / r.total * 100).round(2) : 0 } }
      when "availability"
        scope.group("date_trunc('hour', started_at)")
          .select("date_trunc('hour', started_at) as bucket, COUNT(*) as total, SUM(CASE WHEN NOT error THEN 1 ELSE 0 END) as ok")
          .map { |r| { x: r.bucket.iso8601, y: r.total > 0 ? (r.ok.to_f / r.total * 100).round(2) : 100 } }
      when "p95"
        scope.where.not(duration_ms: nil)
          .group("date_trunc('hour', started_at)")
          .select("date_trunc('hour', started_at) as bucket, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95")
          .map { |r| { x: r.bucket.iso8601, y: r.p95&.round(2) } }
      when "p99"
        scope.where.not(duration_ms: nil)
          .group("date_trunc('hour', started_at)")
          .select("date_trunc('hour', started_at) as bucket, PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms) as p99")
          .map { |r| { x: r.bucket.iso8601, y: r.p99&.round(2) } }
      else
        []
      end.sort_by { |d| d[:x] }
    end
  end
end
