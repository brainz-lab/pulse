module Dashboard
  class NotificationChannelsController < BaseController
    before_action :set_channel, only: [:show, :update, :destroy]

    def index
      @channels = @project.notification_channels.order(:name)
    end

    def show
    end

    def new
      @channel = @project.notification_channels.build(
        kind: 'webhook',
        config: {}
      )
    end

    def create
      @channel = @project.notification_channels.build(channel_params)

      if @channel.save
        AlertsChannel.broadcast_notification_channel_created(@project, @channel)
        redirect_to dashboard_notification_channels_path, notice: 'Notification channel created.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @channel.update(channel_params)
        AlertsChannel.broadcast_notification_channel_updated(@project, @channel)
        redirect_to dashboard_notification_channel_path(@channel), notice: 'Channel updated.'
      else
        render :show, status: :unprocessable_entity
      end
    end

    def destroy
      channel_id = @channel.id
      @channel.destroy
      AlertsChannel.broadcast_notification_channel_deleted(@project, channel_id)
      redirect_to dashboard_notification_channels_path, notice: 'Channel deleted.'
    end

    private

    def set_channel
      @channel = @project.notification_channels.find(params[:id])
    end

    def channel_params
      permitted = params.require(:notification_channel).permit(:name, :kind, :enabled)

      # Build config based on kind
      config = {}
      case params[:notification_channel][:kind]
      when 'webhook'
        config = {
          'url' => params.dig(:notification_channel, :config, :url),
          'headers' => parse_headers(params.dig(:notification_channel, :config, :headers))
        }
      when 'email'
        addresses = params.dig(:notification_channel, :config, :addresses).to_s.split(/[,\s]+/)
        config = { 'addresses' => addresses }
      when 'slack'
        config = {
          'webhook_url' => params.dig(:notification_channel, :config, :webhook_url),
          'channel' => params.dig(:notification_channel, :config, :channel)
        }
      when 'pagerduty'
        config = {
          'integration_key' => params.dig(:notification_channel, :config, :integration_key),
          'severity' => params.dig(:notification_channel, :config, :severity) || 'error'
        }
      end

      permitted[:config] = config
      permitted
    end

    def parse_headers(headers_string)
      return {} if headers_string.blank?

      headers_string.to_s.split("\n").each_with_object({}) do |line, hash|
        key, value = line.split(':', 2).map(&:strip)
        hash[key] = value if key.present? && value.present?
      end
    end
  end
end
