module Dashboard
  class RequestsController < BaseController
    def index
      scope = current_project.traces.requests.recent

      scope = scope.slow(params[:threshold] || 500) if params[:slow]
      scope = scope.errors if params[:errors]

      @pagy, @traces = pagy(scope)
    end

    def show
      @trace = current_project.traces.find_by!(trace_id: params[:id])
    end
  end
end
