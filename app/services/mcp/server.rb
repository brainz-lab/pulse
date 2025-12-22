module Mcp
  class Server
    TOOLS = {
      'pulse_overview' => Tools::PulseOverview,
      'pulse_slow_requests' => Tools::PulseSlowRequests,
      'pulse_throughput' => Tools::PulseThroughput,
      'pulse_errors' => Tools::PulseErrors,
      'pulse_trace' => Tools::PulseTrace,
      'pulse_endpoints' => Tools::PulseEndpoints,
      'pulse_metrics' => Tools::PulseMetrics,
    }.freeze

    def initialize(project)
      @project = project
    end

    def list_tools
      TOOLS.map do |name, klass|
        {
          name: name,
          description: klass::DESCRIPTION,
          inputSchema: klass::SCHEMA
        }
      end
    end

    def call_tool(name, arguments = {})
      tool_class = TOOLS[name]
      raise "Unknown tool: #{name}" unless tool_class
      tool_class.new(@project).call(arguments.symbolize_keys)
    end
  end
end
