module Dashboard
  class TracesController < BaseController
    def index
      # Redirect to requests - traces index is accessed via requests
      redirect_to dashboard_requests_path(params.permit(:kind, :slow, :errors))
    end

    def show
      @trace = current_project.traces.find_by!(trace_id: params[:id])
    end
  end
end
