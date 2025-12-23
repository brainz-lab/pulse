module Dashboard
  class RequestsController < BaseController
    def index
      @traces = current_project.traces.requests.recent

      @traces = @traces.slow(params[:threshold] || 500) if params[:slow]
      @traces = @traces.errors if params[:errors]

      @traces = @traces.limit(100)
    end

    def show
      @trace = current_project.traces.find_by!(trace_id: params[:id])
    end
  end
end
