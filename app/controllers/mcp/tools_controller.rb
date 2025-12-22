module Mcp
  class ToolsController < ActionController::API
    before_action :authenticate!

    # GET /mcp/tools
    def index
      render json: { tools: mcp_server.list_tools }
    end

    # POST /mcp/tools/:name
    def call
      result = mcp_server.call_tool(params[:name], tool_params)
      render json: { result: result }
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST /mcp/rpc - JSON-RPC protocol
    def rpc
      case params[:method]
      when 'tools/list'
        render json: {
          jsonrpc: '2.0',
          id: params[:id],
          result: { tools: mcp_server.list_tools }
        }
      when 'tools/call'
        tool_name = params.dig(:params, :name)
        arguments = params.dig(:params, :arguments) || {}
        result = mcp_server.call_tool(tool_name, arguments)
        render json: {
          jsonrpc: '2.0',
          id: params[:id],
          result: { content: [{ type: 'text', text: result.to_json }] }
        }
      else
        render json: {
          jsonrpc: '2.0',
          id: params[:id],
          error: { code: -32601, message: 'Method not found' }
        }, status: :not_found
      end
    rescue => e
      render json: {
        jsonrpc: '2.0',
        id: params[:id],
        error: { code: -32603, message: e.message }
      }, status: :internal_server_error
    end

    private

    def authenticate!
      raw_key = extract_api_key
      @key_info = PlatformClient.validate_key(raw_key)

      unless @key_info[:valid]
        render json: { error: 'Invalid API key' }, status: :unauthorized
        return
      end

      @current_project = Project.find_or_create_for_platform!(
        platform_project_id: @key_info[:project_id],
        name: @key_info[:project_name],
        environment: @key_info[:environment]
      )
    end

    def extract_api_key
      auth_header = request.headers['Authorization']
      return auth_header.sub(/^Bearer\s+/, '') if auth_header&.start_with?('Bearer ')
      request.headers['X-API-Key'] || params[:api_key]
    end

    def mcp_server
      @mcp_server ||= ::Mcp::Server.new(@current_project)
    end

    def tool_params
      params.except(:controller, :action, :name, :api_key).to_unsafe_h
    end
  end
end
