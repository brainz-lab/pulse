class AlertsChannel < ApplicationCable::Channel
  def subscribed
    project = Project.find_by(id: params[:project_id])
    if project
      stream_for project
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end
end
