module Dashboard
  class TracesController < BaseController
    def index
      @traces = current_project.traces.recent

      @traces = @traces.where(kind: params[:kind]) if params[:kind]
      @traces = @traces.slow(params[:threshold] || 500) if params[:slow]
      @traces = @traces.errors if params[:errors]

      @traces = @traces.limit(100)
    end

    def show
      @trace = current_project.traces.find_by!(trace_id: params[:id])
    end
  end
end
