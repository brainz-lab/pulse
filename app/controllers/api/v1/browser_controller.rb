# frozen_string_literal: true

module Api
  module V1
    # Receives browser performance/network events from brainzlab-js SDK
    class BrowserController < BaseController
      skip_before_action :authenticate!, only: [:preflight, :create]
      skip_before_action :check_feature_access!, only: [:preflight, :create]
      before_action :set_cors_headers
      before_action :find_project_from_token, only: [:create]
      before_action :validate_origin!, only: [:create]

      # OPTIONS /api/v1/browser (CORS preflight)
      def preflight
        head :ok
      end

      # POST /api/v1/browser
      # Receives browser performance and network events
      def create
        events = params[:events] || []
        context = params[:context] || {}
        results = { performance: 0, network: 0 }

        unless @project
          render json: { error: "Project not found" }, status: :not_found
          return
        end

        events.each do |event|
          case event[:type]
          when "performance"
            process_performance_event(event, context)
            results[:performance] += 1
          when "network"
            process_network_event(event, context)
            results[:network] += 1
          end
        end

        render json: {
          status: "ok",
          session_id: request.headers["X-BrainzLab-Session"],
          results: results
        }
      rescue StandardError => e
        Rails.logger.error("[BrowserController] Error: #{e.message}")
        render json: { error: "Failed to process events" }, status: :unprocessable_entity
      end

      private

      def process_performance_event(event, context)
        data = event[:data] || {}
        metric_type = data[:type] || "unknown"

        # Create span for trace waterfall AND metric for dashboards
        case metric_type
        when "LCP", "FCP", "TTFB", "FID", "INP", "CLS"
          create_browser_span(
            kind: "browser.#{metric_type.downcase}",
            name: "Browser #{metric_type}",
            value: data[:value],
            event: event,
            context: context,
            data: {
              rating: data[:rating],
              value: data[:value],
              url: event[:url]
            }
          )
          create_metric(
            name: "browser.#{metric_type.downcase}",
            value: data[:value],
            tags: {
              rating: data[:rating],
              url: event[:url],
              session_id: event[:sessionId]
            },
            context: context
          )
        when "slow_resource"
          create_browser_span(
            kind: "browser.resource",
            name: "Slow Resource: #{data[:name]}",
            value: data[:duration_ms],
            event: event,
            context: context,
            data: {
              resource_name: data[:name],
              initiator_type: data[:initiatorType],
              duration_ms: data[:duration_ms]
            }
          )
          create_metric(
            name: "browser.slow_resource",
            value: data[:duration_ms],
            tags: {
              resource_name: data[:name],
              initiator_type: data[:initiatorType],
              url: event[:url]
            },
            context: context
          )
        end
      end

      def process_network_event(event, context)
        data = event[:data] || {}

        # Create span for trace waterfall AND metric for dashboards
        create_browser_span(
          kind: "browser.network",
          name: "#{data[:method]} #{data[:path]}",
          value: data[:duration_ms] || 0,
          event: event,
          context: context,
          data: {
            method: data[:method],
            path: data[:path],
            status: data[:status],
            host: data[:host],
            duration_ms: data[:duration_ms]
          }
        )
        create_metric(
          name: "browser.network.request",
          value: data[:duration_ms] || 0,
          tags: {
            method: data[:method],
            path: data[:path],
            status: data[:status],
            host: data[:host],
            url: event[:url]
          },
          context: context
        )
      end

      def create_browser_span(kind:, name:, value:, event:, context:, data:)
        return unless @project

        trace_ctx = extract_trace_context
        return unless trace_ctx && trace_ctx[:trace_id]

        # Find the existing trace by trace_id
        trace = Trace.find_by(project: @project, trace_id: trace_ctx[:trace_id])
        return unless trace

        # Create a span linked to the trace
        # For Web Vitals, the value is the metric value (time in ms)
        # The span duration represents when this metric was measured
        now = Time.current
        started_at = event[:timestamp] ? Time.parse(event[:timestamp]) : now

        Span.create!(
          project: @project,
          trace: trace,
          span_id: "browser_#{SecureRandom.hex(8)}",
          parent_span_id: trace_ctx[:parent_span_id] || trace_ctx[:span_id],
          name: name,
          kind: kind,
          started_at: started_at,
          ended_at: started_at, # Instantaneous measurement
          duration_ms: value.to_f, # Store the metric value as duration
          data: data.merge(
            source: "browser",
            session_id: event[:sessionId],
            url: event[:url],
            user_agent: event[:userAgent]
          ).compact
        )
      rescue StandardError => e
        Rails.logger.warn("[BrowserController] Failed to create browser span: #{e.message}")
      end

      def create_metric(name:, value:, tags:, context:)
        return unless @project
        return unless value

        # Find or create the metric definition
        metric = Metric.find_or_create_by!(project: @project, name: name) do |m|
          m.kind = "gauge"
          m.tags = { source: "browser" }
        end

        # Include trace context in tags for correlation
        trace_ctx = extract_trace_context
        if trace_ctx
          tags = tags.merge(
            trace_id: trace_ctx[:trace_id],
            parent_span_id: trace_ctx[:parent_span_id] || trace_ctx[:span_id]
          ).compact
        end

        # Create the metric point with the value
        MetricPoint.create!(
          project: @project,
          metric: metric,
          value: value.to_f,
          tags: tags.compact,
          timestamp: Time.current
        )
      rescue StandardError => e
        Rails.logger.warn("[BrowserController] Failed to create metric: #{e.message}")
      end

      def find_project_from_token
        token = extract_browser_token
        return unless token

        # Prefer ingest_key for browser access (write-only, safe for browser exposure)
        if token.start_with?("pls_ingest_")
          @project = Project.find_by("settings->>'ingest_key' = ?", token)
        elsif token.start_with?("pls_api_")
          # Accept api_key but log warning - should use ingest_key for browser
          @project = Project.find_by("settings->>'api_key' = ?", token)
          Rails.logger.warn("[BrowserController] API key used for browser endpoint - consider using ingest_key")
        elsif token.start_with?("pls_")
          # Legacy key format - try both
          @project = Project.find_by("settings->>'ingest_key' = ?", token) ||
                     Project.find_by("settings->>'api_key' = ?", token)
        else
          # Try to find by project_id from context
          project_id = params.dig(:context, :projectId)
          @project = Project.find_by(platform_project_id: project_id) if project_id
        end
      end

      def validate_origin!
        return unless @project

        # Skip validation in development
        return if Rails.env.development?

        # Skip validation for localhost origins
        origin = request.headers["Origin"]
        return if origin_is_localhost?(origin)

        # Validate against allowed_origins
        unless origin_allowed?(origin)
          render json: { error: "Origin not allowed" }, status: :forbidden
        end
      end

      def origin_allowed?(origin)
        allowed = @project.settings&.dig("allowed_origins")
        return true if allowed.blank? # No restriction if empty
        allowed.include?(origin)
      end

      def origin_is_localhost?(origin)
        return false if origin.blank?
        uri = URI.parse(origin)
        uri.host == "localhost" || uri.host == "127.0.0.1" || uri.host&.end_with?(".localhost")
      rescue URI::InvalidURIError
        false
      end

      def extract_browser_token
        auth_header = request.headers["Authorization"]
        return auth_header.sub(/^Bearer\s+/, "") if auth_header&.start_with?("Bearer ")
        request.headers["X-API-Key"]
      end

      def set_cors_headers
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-API-Key, X-BrainzLab-Session, traceparent, tracestate"
        response.headers["Access-Control-Max-Age"] = "86400"
      end

      # Extract trace context from request (W3C Trace Context format or body)
      def extract_trace_context
        # Try traceparent header first (W3C Trace Context)
        traceparent = request.headers["traceparent"] || request.headers["HTTP_TRACEPARENT"]
        if traceparent
          parts = traceparent.split("-")
          if parts.length >= 4
            return {
              trace_id: parts[1],
              span_id: parts[2],
              sampled: (parts[3].to_i(16) & 0x01) == 1
            }
          end
        end

        # Fallback to body context
        context = params[:context] || {}
        if context[:traceId]
          return {
            trace_id: context[:traceId],
            parent_span_id: context[:parentSpanId],
            sampled: true
          }
        end

        nil
      end
    end
  end
end
