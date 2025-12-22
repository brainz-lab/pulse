class MetricsChannel < ApplicationCable::Channel
  def subscribed
    project_id = params[:project_id]
    stream_from "metrics_#{project_id}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
