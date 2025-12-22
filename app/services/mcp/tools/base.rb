module Mcp
  module Tools
    class Base
      def initialize(project)
        @project = project
      end

      def call(args)
        raise NotImplementedError
      end

      protected

      def parse_since(value)
        case value
        when /^(\d+)m$/ then $1.to_i.minutes.ago
        when /^(\d+)h$/ then $1.to_i.hours.ago
        when /^(\d+)d$/ then $1.to_i.days.ago
        else 1.hour.ago
        end
      end
    end
  end
end
