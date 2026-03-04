module Dashboard
  class RequestsController < BaseController
    def index
      @since = parse_since(params[:since])
      scope = current_project.traces.requests.where("started_at >= ?", @since)

      scope = scope.slow(params[:threshold]&.to_i || 500) if params[:slow].present?
      scope = scope.errors if params[:errors].present?
      scope = scope.where(controller: params[:controller_name]) if params[:controller_name].present?
      scope = scope.where(request_method: params[:method]) if params[:method].present?
      scope = scope.where("duration_ms >= ?", params[:min_duration].to_f) if params[:min_duration].present?
      scope = scope.where("duration_ms <= ?", params[:max_duration].to_f) if params[:max_duration].present?
      scope = scope.where(host: params[:host]) if params[:host].present?
      scope = scope.where(environment: params[:environment]) if params[:environment].present?
      scope = scope.order(started_at: :desc)

      @pagy, @traces = pagy(scope)

      # For filter dropdowns
      @controllers = current_project.traces.requests
        .where("started_at >= ?", @since)
        .distinct.pluck(:controller).compact.sort
      @hosts = current_project.traces.requests
        .where("started_at >= ?", @since)
        .distinct.pluck(:host).compact.sort
      @environments = current_project.traces.requests
        .where("started_at >= ?", @since)
        .distinct.pluck(:environment).compact.sort
    end

    def show
      @trace = current_project.traces.includes(:spans).find_by!(trace_id: params[:id])
    end

    private

    def parse_since(value)
      case value
      when "6h" then 6.hours.ago
      when "24h" then 24.hours.ago
      when "7d" then 7.days.ago
      else 1.hour.ago
      end
    end
  end
end
