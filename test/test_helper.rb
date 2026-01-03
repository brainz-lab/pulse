# frozen_string_literal: true

require "simplecov"
SimpleCov.start "rails" do
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/vendor/"
  
  add_group "Controllers", "app/controllers"
  add_group "Models", "app/models"
  add_group "Services", "app/services"
  add_group "Jobs", "app/jobs"
  add_group "Mailers", "app/mailers"
  add_group "Channels", "app/channels"
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Helper to create a test project
    def create_test_project(attrs = {})
      Project.create!(
        platform_project_id: attrs[:platform_project_id] || SecureRandom.uuid,
        name: attrs[:name] || "Test Project",
        environment: attrs[:environment] || "test",
        apdex_t: attrs[:apdex_t] || 0.5
      )
    end

    # Helper to create a test trace
    def create_test_trace(project, attrs = {})
      project.traces.create!(
        trace_id: attrs[:trace_id] || SecureRandom.hex(16),
        name: attrs[:name] || "GET /test",
        kind: attrs[:kind] || "request",
        started_at: attrs[:started_at] || Time.current,
        ended_at: attrs[:ended_at],
        duration_ms: attrs[:duration_ms],
        request_method: attrs[:request_method] || "GET",
        request_path: attrs[:request_path] || "/test",
        status: attrs[:status] || 200,
        error: attrs[:error] || false,
        environment: attrs[:environment]
      )
    end

    # Helper to create a test span
    def create_test_span(trace, attrs = {})
      span_attrs = {
        project: trace.project,
        span_id: attrs[:span_id] || SecureRandom.hex(8),
        name: attrs[:name] || "Test Span",
        kind: attrs[:kind] || "db",
        started_at: attrs[:started_at] || trace.started_at,
        ended_at: attrs[:ended_at],
        data: attrs[:data] || {}
      }
      # Only set duration_ms if explicitly provided or if ended_at is not provided
      span_attrs[:duration_ms] = attrs[:duration_ms] || 10.0 unless attrs[:ended_at] && !attrs.key?(:duration_ms)

      trace.spans.create!(span_attrs)
    end

    # Helper to create a test metric
    def create_test_metric(project, attrs = {})
      project.metrics.create!(
        name: attrs[:name] || "test.metric",
        kind: attrs[:kind] || "gauge",
        description: attrs[:description],
        tags: attrs[:tags] || {}
      )
    end
  end
end
