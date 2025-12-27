# Claude Code Prompt: Build Pulse by Brainz Lab

## Project Overview

Build **Pulse** - APM and performance monitoring for Rails apps. Third product in the Brainz Lab suite.

> *"Your app's vital signs"*
> 
> pulse.brainzlab.ai

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│                              PULSE                                           │
│                     "Keep your finger on the pulse"                         │
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐    │
│   │  Requests   │   │   Traces    │   │   Metrics   │   │   Alerts    │    │
│   │             │   │             │   │             │   │             │    │
│   │  Response   │   │  Distributed│   │  Custom     │   │  Threshold  │    │
│   │  times      │   │  tracing    │   │  metrics    │   │  alerts     │    │
│   └─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘    │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                         DASHBOARD                                    │   │
│   │                                                                      │   │
│   │   Apdex: 0.94    P95: 245ms    Throughput: 1.2K rpm    Errors: 0.1% │   │
│   │                                                                      │   │
│   │   ████████████████████░░░░  Response Time Distribution              │   │
│   │   ▁▂▃▅▆▇█▇▆▅▃▂▁            Throughput Over Time                    │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│                              PULSE                                           │
│                         (Rails 8 App)                                        │
│                                                                              │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐            │
│   │   Dashboard     │  │      API        │  │   MCP Server    │            │
│   │   (Hotwire)     │  │   (JSON API)    │  │   (Ruby)        │            │
│   │                 │  │                 │  │                 │            │
│   │  /dashboard/*   │  │  /api/v1/*      │  │  /mcp/*         │            │
│   └─────────────────┘  └─────────────────┘  └─────────────────┘            │
│                              │                      │                       │
│                              ▼                      ▼                       │
│                    ┌─────────────────────────────────────┐                 │
│                    │         PostgreSQL + TimescaleDB    │                 │
│                    │         (for time-series data)      │                 │
│                    └─────────────────────────────────────┘                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                       ▲
                                       │
                    ┌──────────────────┴──────────────────┐
                    │                                      │
            ┌───────┴───────┐                    ┌────────┴────────┐
            │  SDK (Gem)    │                    │  Claude/AI      │
            │               │                    │                 │
            │ brainzlab-sdk │                    │  Uses MCP       │
            │               │                    │  tools          │
            └───────────────┘                    └─────────────────┘
```

## Tech Stack

- **Backend**: Rails 8 API + Dashboard
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **Database**: PostgreSQL with TimescaleDB extension (for time-series)
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **WebSockets**: Solid Cable (real-time metrics)
- **Charts**: Chart.js or Recharts (via Stimulus)
- **MCP Server**: Ruby (inside Rails app)

## Project Structure

```
pulse/
├── Gemfile
├── Dockerfile
├── docker-compose.yml
├── config/
│   ├── routes.rb
│   └── initializers/
│       └── timescale.rb
├── app/
│   ├── controllers/
│   │   ├── api/v1/
│   │   │   ├── base_controller.rb
│   │   │   ├── traces_controller.rb
│   │   │   ├── metrics_controller.rb
│   │   │   └── spans_controller.rb
│   │   ├── dashboard/
│   │   │   ├── base_controller.rb
│   │   │   ├── overview_controller.rb
│   │   │   ├── requests_controller.rb
│   │   │   ├── traces_controller.rb
│   │   │   └── metrics_controller.rb
│   │   ├── mcp/
│   │   │   └── tools_controller.rb
│   │   └── sso_controller.rb
│   ├── models/
│   │   ├── project.rb
│   │   ├── trace.rb
│   │   ├── span.rb
│   │   ├── metric.rb
│   │   └── metric_point.rb
│   ├── services/
│   │   ├── trace_processor.rb
│   │   ├── metrics_aggregator.rb
│   │   ├── apdex_calculator.rb
│   │   ├── platform_client.rb
│   │   └── mcp/
│   │       ├── server.rb
│   │       └── tools/
│   │           ├── base.rb
│   │           ├── pulse_overview.rb
│   │           ├── pulse_slow_requests.rb
│   │           ├── pulse_throughput.rb
│   │           ├── pulse_errors.rb
│   │           ├── pulse_trace.rb
│   │           └── pulse_metrics.rb
│   ├── jobs/
│   │   ├── aggregate_metrics_job.rb
│   │   └── cleanup_old_data_job.rb
│   ├── channels/
│   │   └── metrics_channel.rb
│   ├── views/
│   │   ├── layouts/
│   │   │   └── dashboard.html.erb
│   │   └── dashboard/
│   │       ├── overview/
│   │       │   └── show.html.erb
│   │       ├── requests/
│   │       │   ├── index.html.erb
│   │       │   └── show.html.erb
│   │       └── traces/
│   │           ├── index.html.erb
│   │           └── show.html.erb
│   └── javascript/
│       └── controllers/
│           ├── chart_controller.js
│           ├── sparkline_controller.js
│           └── live_metrics_controller.js
```

---

## Database Schema

```ruby
# db/migrate/001_create_projects.rb

class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    
    create_table :projects, id: :uuid do |t|
      t.string :platform_project_id, null: false
      t.string :name
      t.string :environment, default: 'live'
      
      # Apdex configuration
      t.float :apdex_t, default: 0.5  # Satisfying threshold in seconds
      
      t.timestamps
      
      t.index :platform_project_id, unique: true
    end
  end
end

# db/migrate/002_create_traces.rb

class CreateTraces < ActiveRecord::Migration[8.0]
  def change
    create_table :traces, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      
      # Identification
      t.string :trace_id, null: false              # Unique trace ID
      t.string :name, null: false                   # "GET /users" or "ProcessOrderJob"
      t.string :kind, null: false, default: 'request'  # request, job, custom
      
      # Timing
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.float :duration_ms                          # Total duration in ms
      
      # Request context
      t.string :request_id
      t.string :request_method
      t.string :request_path
      t.string :controller
      t.string :action
      t.integer :status
      
      # Job context
      t.string :job_class
      t.string :job_id
      t.string :queue
      
      # Environment
      t.string :environment
      t.string :commit
      t.string :host
      
      # User
      t.string :user_id
      
      # Status
      t.boolean :error, default: false
      t.string :error_class
      t.text :error_message
      
      # Metrics
      t.integer :span_count, default: 0
      t.float :db_duration_ms, default: 0
      t.float :view_duration_ms, default: 0
      t.float :external_duration_ms, default: 0
      
      t.index [:project_id, :started_at]
      t.index [:project_id, :name, :started_at]
      t.index :trace_id, unique: true
      t.index :request_id
    end
    
    # Make it a TimescaleDB hypertable for efficient time-series queries
    execute "SELECT create_hypertable('traces', 'started_at', if_not_exists => TRUE);"
  end
end

# db/migrate/003_create_spans.rb

class CreateSpans < ActiveRecord::Migration[8.0]
  def change
    create_table :spans, id: :uuid do |t|
      t.references :trace, type: :uuid, null: false, foreign_key: true
      t.references :project, type: :uuid, null: false, foreign_key: true
      
      t.string :span_id, null: false
      t.string :parent_span_id                      # For nested spans
      
      t.string :name, null: false                   # "SQL SELECT", "Redis GET", etc.
      t.string :kind, null: false                   # db, http, cache, render, custom
      
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.float :duration_ms
      
      # Details based on kind
      t.jsonb :data, default: {}
      # For db: { sql: "...", table: "users", operation: "SELECT" }
      # For http: { url: "...", method: "GET", status: 200 }
      # For cache: { key: "...", hit: true }
      # For render: { template: "...", layout: "..." }
      
      t.boolean :error, default: false
      t.string :error_class
      t.text :error_message
      
      t.index [:trace_id, :started_at]
      t.index :span_id
    end
    
    execute "SELECT create_hypertable('spans', 'started_at', if_not_exists => TRUE);"
  end
end

# db/migrate/004_create_metrics.rb

class CreateMetrics < ActiveRecord::Migration[8.0]
  def change
    # Metric definitions
    create_table :metrics, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      
      t.string :name, null: false                   # "checkout.duration", "cache.hit_rate"
      t.string :kind, null: false, default: 'gauge' # gauge, counter, histogram
      t.string :unit                                # ms, bytes, percent, count
      t.text :description
      
      t.jsonb :tags, default: {}                    # Default tags
      
      t.timestamps
      
      t.index [:project_id, :name], unique: true
    end
  end
end

# db/migrate/005_create_metric_points.rb

class CreateMetricPoints < ActiveRecord::Migration[8.0]
  def change
    create_table :metric_points, id: false do |t|  # No id for hypertable efficiency
      t.references :project, type: :uuid, null: false
      t.references :metric, type: :uuid, null: false
      
      t.datetime :timestamp, null: false
      t.float :value, null: false
      
      t.jsonb :tags, default: {}                    # Instance tags
      
      t.index [:project_id, :metric_id, :timestamp]
    end
    
    execute "SELECT create_hypertable('metric_points', 'timestamp', if_not_exists => TRUE);"
    
    # Compression policy for old data
    execute "ALTER TABLE metric_points SET (timescaledb.compress);"
    execute "SELECT add_compression_policy('metric_points', INTERVAL '7 days');"
    
    # Retention policy
    execute "SELECT add_retention_policy('metric_points', INTERVAL '30 days');"
  end
end

# db/migrate/006_create_aggregated_metrics.rb

class CreateAggregatedMetrics < ActiveRecord::Migration[8.0]
  def change
    # Pre-aggregated metrics for fast dashboard queries
    create_table :aggregated_metrics, id: false do |t|
      t.references :project, type: :uuid, null: false
      
      t.string :name, null: false                   # "requests", "apdex", "error_rate"
      t.datetime :bucket, null: false               # Rounded to minute/hour/day
      t.string :granularity, null: false            # minute, hour, day
      
      t.float :count
      t.float :sum
      t.float :min
      t.float :max
      t.float :avg
      t.float :p50
      t.float :p95
      t.float :p99
      
      t.jsonb :dimensions, default: {}              # { controller: "users", action: "show" }
      
      t.index [:project_id, :name, :bucket, :granularity], name: 'idx_agg_metrics_lookup'
    end
    
    execute "SELECT create_hypertable('aggregated_metrics', 'bucket', if_not_exists => TRUE);"
  end
end
```

---

## Models

```ruby
# app/models/project.rb

class Project < ApplicationRecord
  has_many :traces, dependent: :destroy
  has_many :spans, dependent: :destroy
  has_many :metrics, dependent: :destroy
  has_many :metric_points, dependent: :destroy
  
  validates :platform_project_id, presence: true, uniqueness: true
  
  def self.find_or_create_for_platform!(platform_project_id:, name: nil, environment: 'live')
    find_or_create_by!(platform_project_id: platform_project_id) do |p|
      p.name = name
      p.environment = environment
    end
  end
  
  # Apdex score for a time range
  def apdex(since: 1.hour.ago)
    traces_in_range = traces.where('started_at >= ?', since).where(kind: 'request')
    
    ApdexCalculator.calculate(
      traces: traces_in_range,
      threshold: apdex_t
    )
  end
  
  # Key metrics summary
  def overview(since: 1.hour.ago)
    traces_scope = traces.where('started_at >= ?', since).where(kind: 'request')
    
    {
      apdex: apdex(since: since),
      throughput: traces_scope.count,
      rpm: (traces_scope.count / ((Time.current - since) / 60.0)).round(1),
      avg_duration: traces_scope.average(:duration_ms)&.round(2),
      p95_duration: percentile(traces_scope, :duration_ms, 0.95),
      p99_duration: percentile(traces_scope, :duration_ms, 0.99),
      error_rate: error_rate(traces_scope),
      error_count: traces_scope.where(error: true).count
    }
  end
  
  private
  
  def percentile(scope, column, p)
    scope.order(column).offset((scope.count * p).to_i).limit(1).pick(column)
  end
  
  def error_rate(scope)
    total = scope.count
    return 0 if total == 0
    (scope.where(error: true).count.to_f / total * 100).round(2)
  end
end

# app/models/trace.rb

class Trace < ApplicationRecord
  belongs_to :project
  has_many :spans, dependent: :destroy
  
  KINDS = %w[request job custom].freeze
  
  validates :trace_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :started_at, presence: true
  
  scope :requests, -> { where(kind: 'request') }
  scope :jobs, -> { where(kind: 'job') }
  scope :recent, -> { order(started_at: :desc) }
  scope :slow, ->(threshold = 1000) { where('duration_ms > ?', threshold) }
  scope :errors, -> { where(error: true) }
  
  before_save :calculate_duration, if: -> { ended_at.present? && duration_ms.nil? }
  
  def complete!(ended_at: Time.current, error: false, error_class: nil, error_message: nil)
    update!(
      ended_at: ended_at,
      error: error,
      error_class: error_class,
      error_message: error_message
    )
  end
  
  def add_span!(attributes)
    span = spans.create!(attributes.merge(project: project))
    
    # Update aggregate metrics on trace
    recalculate_span_metrics!
    
    span
  end
  
  def waterfall
    spans.order(:started_at).map do |span|
      {
        id: span.span_id,
        parent_id: span.parent_span_id,
        name: span.name,
        kind: span.kind,
        started_at: span.started_at,
        duration_ms: span.duration_ms,
        offset_ms: ((span.started_at - started_at) * 1000).round(2),
        data: span.data,
        error: span.error
      }
    end
  end
  
  def apdex_category(threshold = nil)
    threshold ||= project.apdex_t
    duration_s = duration_ms / 1000.0
    
    if duration_s <= threshold
      :satisfied
    elsif duration_s <= threshold * 4
      :tolerating
    else
      :frustrated
    end
  end
  
  private
  
  def calculate_duration
    self.duration_ms = ((ended_at - started_at) * 1000).round(2)
  end
  
  def recalculate_span_metrics!
    self.span_count = spans.count
    self.db_duration_ms = spans.where(kind: 'db').sum(:duration_ms)
    self.view_duration_ms = spans.where(kind: 'render').sum(:duration_ms)
    self.external_duration_ms = spans.where(kind: 'http').sum(:duration_ms)
    save!
  end
end

# app/models/span.rb

class Span < ApplicationRecord
  belongs_to :trace
  belongs_to :project
  
  KINDS = %w[db http cache render custom].freeze
  
  validates :span_id, presence: true
  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :started_at, presence: true
  
  scope :db, -> { where(kind: 'db') }
  scope :http, -> { where(kind: 'http') }
  scope :cache, -> { where(kind: 'cache') }
  scope :slow, ->(threshold = 100) { where('duration_ms > ?', threshold) }
  
  before_save :calculate_duration, if: -> { ended_at.present? && duration_ms.nil? }
  
  # Formatted display
  def display_name
    case kind
    when 'db'
      operation = data['operation'] || 'SQL'
      table = data['table']
      table ? "#{operation} #{table}" : operation
    when 'http'
      "#{data['method']} #{data['url']}"
    when 'cache'
      hit = data['hit'] ? 'HIT' : 'MISS'
      "Cache #{hit}: #{data['key']}"
    when 'render'
      "Render #{data['template']}"
    else
      name
    end
  end
  
  private
  
  def calculate_duration
    self.duration_ms = ((ended_at - started_at) * 1000).round(2)
  end
end

# app/models/metric.rb

class Metric < ApplicationRecord
  belongs_to :project
  has_many :points, class_name: 'MetricPoint', dependent: :destroy
  
  KINDS = %w[gauge counter histogram].freeze
  
  validates :name, presence: true, uniqueness: { scope: :project_id }
  validates :kind, inclusion: { in: KINDS }
  
  def record!(value, tags: {}, timestamp: Time.current)
    points.create!(
      project: project,
      timestamp: timestamp,
      value: value,
      tags: self.tags.merge(tags)
    )
  end
  
  def stats(since: 1.hour.ago, granularity: :minute)
    points
      .where('timestamp >= ?', since)
      .group("date_trunc('#{granularity}', timestamp)")
      .select(
        "date_trunc('#{granularity}', timestamp) as bucket",
        'COUNT(*) as count',
        'AVG(value) as avg',
        'MIN(value) as min',
        'MAX(value) as max',
        'SUM(value) as sum'
      )
      .order('bucket')
  end
end

# app/models/metric_point.rb

class MetricPoint < ApplicationRecord
  belongs_to :project
  belongs_to :metric
  
  validates :timestamp, presence: true
  validates :value, presence: true
end
```

---

## Services

```ruby
# app/services/trace_processor.rb

class TraceProcessor
  def initialize(project:, payload:)
    @project = project
    @payload = payload.deep_symbolize_keys
  end
  
  def process!
    trace = find_or_create_trace
    
    # Process spans if included
    if @payload[:spans].present?
      @payload[:spans].each do |span_data|
        create_span(trace, span_data)
      end
    end
    
    # Complete trace if ended_at is provided
    if @payload[:ended_at]
      trace.complete!(
        ended_at: parse_timestamp(@payload[:ended_at]),
        error: @payload[:error] || false,
        error_class: @payload[:error_class],
        error_message: @payload[:error_message]
      )
    end
    
    # Broadcast for real-time dashboard
    broadcast_trace(trace)
    
    # Update aggregated metrics
    update_aggregates(trace) if trace.ended_at.present?
    
    trace
  end
  
  private
  
  def find_or_create_trace
    @project.traces.find_or_create_by!(trace_id: @payload[:trace_id]) do |t|
      t.name = @payload[:name] || build_name
      t.kind = @payload[:kind] || 'request'
      t.started_at = parse_timestamp(@payload[:started_at]) || Time.current
      
      t.request_id = @payload[:request_id]
      t.request_method = @payload[:request_method]
      t.request_path = @payload[:request_path]
      t.controller = @payload[:controller]
      t.action = @payload[:action]
      t.status = @payload[:status]
      
      t.job_class = @payload[:job_class]
      t.job_id = @payload[:job_id]
      t.queue = @payload[:queue]
      
      t.environment = @payload[:environment]
      t.commit = @payload[:commit]
      t.host = @payload[:host]
      t.user_id = @payload[:user_id]
    end
  end
  
  def create_span(trace, span_data)
    trace.spans.create!(
      project: @project,
      span_id: span_data[:span_id] || SecureRandom.hex(8),
      parent_span_id: span_data[:parent_span_id],
      name: span_data[:name],
      kind: span_data[:kind] || 'custom',
      started_at: parse_timestamp(span_data[:started_at]) || Time.current,
      ended_at: parse_timestamp(span_data[:ended_at]),
      duration_ms: span_data[:duration_ms],
      data: span_data[:data] || {},
      error: span_data[:error] || false,
      error_class: span_data[:error_class],
      error_message: span_data[:error_message]
    )
  end
  
  def build_name
    if @payload[:request_method] && @payload[:request_path]
      "#{@payload[:request_method]} #{normalize_path(@payload[:request_path])}"
    elsif @payload[:job_class]
      @payload[:job_class]
    else
      'Unknown'
    end
  end
  
  def normalize_path(path)
    # Replace IDs with :id for grouping
    path.gsub(/\/\d+/, '/:id').gsub(/\/[a-f0-9-]{36}/, '/:uuid')
  end
  
  def parse_timestamp(ts)
    case ts
    when Time, DateTime then ts
    when String then Time.parse(ts)
    when Numeric then Time.at(ts)
    else nil
    end
  rescue
    nil
  end
  
  def broadcast_trace(trace)
    MetricsChannel.broadcast_to(@project, {
      type: 'trace',
      trace: {
        id: trace.id,
        name: trace.name,
        duration_ms: trace.duration_ms,
        status: trace.status,
        error: trace.error
      }
    })
  end
  
  def update_aggregates(trace)
    AggregateMetricsJob.perform_later(trace.id)
  end
end

# app/services/apdex_calculator.rb

class ApdexCalculator
  # Apdex = (Satisfied + Tolerating/2) / Total
  #
  # Satisfied: duration <= T
  # Tolerating: T < duration <= 4T
  # Frustrated: duration > 4T
  
  def self.calculate(traces:, threshold:)
    total = traces.count
    return 1.0 if total == 0
    
    threshold_ms = threshold * 1000
    
    satisfied = traces.where('duration_ms <= ?', threshold_ms).count
    tolerating = traces.where('duration_ms > ? AND duration_ms <= ?', threshold_ms, threshold_ms * 4).count
    
    ((satisfied + (tolerating / 2.0)) / total).round(2)
  end
end

# app/services/metrics_aggregator.rb

class MetricsAggregator
  def initialize(project:)
    @project = project
  end
  
  def aggregate_minute!(timestamp)
    bucket = timestamp.beginning_of_minute
    
    traces = @project.traces
      .where(started_at: bucket...bucket + 1.minute)
      .where(kind: 'request')
      .where.not(duration_ms: nil)
    
    return if traces.empty?
    
    durations = traces.pluck(:duration_ms).sort
    
    create_or_update_aggregate(
      name: 'request_duration',
      bucket: bucket,
      granularity: 'minute',
      values: durations
    )
    
    create_or_update_aggregate(
      name: 'throughput',
      bucket: bucket,
      granularity: 'minute',
      values: [traces.count]
    )
    
    error_count = traces.where(error: true).count
    create_or_update_aggregate(
      name: 'error_rate',
      bucket: bucket,
      granularity: 'minute',
      values: [(error_count.to_f / traces.count * 100).round(2)]
    )
  end
  
  private
  
  def create_or_update_aggregate(name:, bucket:, granularity:, values:, dimensions: {})
    sorted = values.sort
    
    AggregatedMetric.upsert({
      project_id: @project.id,
      name: name,
      bucket: bucket,
      granularity: granularity,
      count: values.count,
      sum: values.sum,
      min: sorted.first,
      max: sorted.last,
      avg: (values.sum.to_f / values.count).round(2),
      p50: percentile(sorted, 0.50),
      p95: percentile(sorted, 0.95),
      p99: percentile(sorted, 0.99),
      dimensions: dimensions
    }, unique_by: [:project_id, :name, :bucket, :granularity])
  end
  
  def percentile(sorted_values, p)
    return nil if sorted_values.empty?
    index = (sorted_values.length * p).ceil - 1
    sorted_values[[index, 0].max]
  end
end
```

---

## API Controllers

```ruby
# app/controllers/api/v1/base_controller.rb

module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate!
      before_action :check_feature_access!
      
      attr_reader :current_project, :key_info
      
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
      
      def check_feature_access!
        unless @key_info.dig(:features, :pulse)
          render json: { 
            error: 'Pulse is not included in your plan',
            upgrade_url: 'https://brainzlab.ai/pricing'
          }, status: :forbidden
        end
      end
      
      def extract_api_key
        auth_header = request.headers['Authorization']
        return auth_header.sub(/^Bearer\s+/, '') if auth_header&.start_with?('Bearer ')
        request.headers['X-API-Key'] || params[:api_key]
      end
      
      def track_usage!(count = 1)
        PlatformClient.track_usage(
          project_id: @key_info[:project_id],
          product: 'pulse',
          metric: 'traces',
          count: count
        )
      end
    end
  end
end

# app/controllers/api/v1/traces_controller.rb

module Api
  module V1
    class TracesController < BaseController
      # POST /api/v1/traces
      def create
        trace = TraceProcessor.new(
          project: current_project,
          payload: trace_params.to_h
        ).process!
        
        track_usage!(1)
        
        render json: {
          id: trace.id,
          trace_id: trace.trace_id
        }, status: :created
      end
      
      # POST /api/v1/traces/batch
      def batch
        traces_data = params[:traces] || params[:_json] || []
        results = []
        
        traces_data.each do |trace_payload|
          trace = TraceProcessor.new(
            project: current_project,
            payload: trace_payload.to_h
          ).process!
          
          results << { id: trace.id, trace_id: trace.trace_id }
        end
        
        track_usage!(results.size)
        
        render json: { processed: results.size, results: results }, status: :created
      end
      
      # GET /api/v1/traces
      def index
        traces = current_project.traces.recent
        
        traces = traces.where(kind: params[:kind]) if params[:kind]
        traces = traces.where(controller: params[:controller]) if params[:controller]
        traces = traces.slow(params[:slow].to_f) if params[:slow]
        traces = traces.errors if params[:errors] == 'true'
        
        if params[:since]
          since = Time.parse(params[:since]) rescue nil
          traces = traces.where('started_at >= ?', since) if since
        end
        
        traces = traces.limit(params[:limit] || 50)
        
        render json: { traces: traces.as_json(except: [:created_at, :updated_at]) }
      end
      
      # GET /api/v1/traces/:id
      def show
        trace = current_project.traces.find(params[:id])
        
        render json: {
          trace: trace,
          spans: trace.waterfall
        }
      end
      
      private
      
      def trace_params
        params.permit(
          :trace_id, :name, :kind,
          :started_at, :ended_at, :duration_ms,
          :request_id, :request_method, :request_path, :controller, :action, :status,
          :job_class, :job_id, :queue,
          :environment, :commit, :host, :user_id,
          :error, :error_class, :error_message,
          spans: [:span_id, :parent_span_id, :name, :kind, :started_at, :ended_at, :duration_ms, :error, :error_class, :error_message, data: {}]
        )
      end
    end
  end
end

# app/controllers/api/v1/metrics_controller.rb

module Api
  module V1
    class MetricsController < BaseController
      # POST /api/v1/metrics
      def create
        metric = current_project.metrics.find_or_create_by!(name: params[:name]) do |m|
          m.kind = params[:kind] || 'gauge'
          m.unit = params[:unit]
          m.description = params[:description]
        end
        
        metric.record!(
          params[:value].to_f,
          tags: params[:tags] || {},
          timestamp: params[:timestamp] ? Time.parse(params[:timestamp]) : Time.current
        )
        
        render json: { metric_id: metric.id }, status: :created
      end
      
      # POST /api/v1/metrics/batch
      def batch
        metrics_data = params[:metrics] || params[:_json] || []
        count = 0
        
        metrics_data.each do |m|
          metric = current_project.metrics.find_or_create_by!(name: m[:name]) do |new_m|
            new_m.kind = m[:kind] || 'gauge'
          end
          
          metric.record!(m[:value].to_f, tags: m[:tags] || {})
          count += 1
        end
        
        render json: { processed: count }, status: :created
      end
      
      # GET /api/v1/metrics
      def index
        metrics = current_project.metrics
        
        render json: { metrics: metrics }
      end
      
      # GET /api/v1/metrics/:name/stats
      def stats
        metric = current_project.metrics.find_by!(name: params[:name])
        since = params[:since] ? Time.parse(params[:since]) : 1.hour.ago
        granularity = params[:granularity] || 'minute'
        
        render json: { stats: metric.stats(since: since, granularity: granularity.to_sym) }
      end
      
      # GET /api/v1/overview
      def overview
        since = params[:since] ? Time.parse(params[:since]) : 1.hour.ago
        
        render json: current_project.overview(since: since)
      end
    end
  end
end
```

---

## MCP Tools

```ruby
# app/services/mcp/server.rb

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

# app/services/mcp/tools/pulse_overview.rb

module Mcp
  module Tools
    class PulseOverview < Base
      DESCRIPTION = "Get application health overview: Apdex score, throughput, " \
        "response times (avg, p95, p99), and error rate."
      
      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", default: "1h", description: "Time range (1h, 24h, 7d)" }
        }
      }.freeze

      def call(args)
        since = parse_since(args[:since] || '1h')
        @project.overview(since: since)
      end
      
      private
      
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

# app/services/mcp/tools/pulse_slow_requests.rb

module Mcp
  module Tools
    class PulseSlowRequests < Base
      DESCRIPTION = "Get slowest requests. Useful for finding performance bottlenecks."
      
      SCHEMA = {
        type: "object",
        properties: {
          threshold_ms: { type: "number", default: 1000, description: "Min duration in ms" },
          since: { type: "string", default: "1h", description: "Time range" },
          limit: { type: "integer", default: 20, description: "Max results" }
        }
      }.freeze

      def call(args)
        since = parse_since(args[:since] || '1h')
        threshold = args[:threshold_ms] || 1000
        limit = args[:limit] || 20
        
        traces = @project.traces
          .requests
          .where('started_at >= ?', since)
          .where('duration_ms >= ?', threshold)
          .order(duration_ms: :desc)
          .limit(limit)
        
        {
          slow_requests: traces.map { |t| format_trace(t) },
          threshold_ms: threshold,
          count: traces.size
        }
      end
      
      private
      
      def format_trace(trace)
        {
          id: trace.id,
          name: trace.name,
          duration_ms: trace.duration_ms,
          started_at: trace.started_at,
          controller: trace.controller,
          action: trace.action,
          status: trace.status,
          db_ms: trace.db_duration_ms,
          view_ms: trace.view_duration_ms,
          span_count: trace.span_count
        }
      end
      
      def parse_since(value)
        case value
        when /^(\d+)h$/ then $1.to_i.hours.ago
        when /^(\d+)d$/ then $1.to_i.days.ago
        else 1.hour.ago
        end
      end
    end
  end
end

# app/services/mcp/tools/pulse_throughput.rb

module Mcp
  module Tools
    class PulseThroughput < Base
      DESCRIPTION = "Get request throughput over time (requests per minute)."
      
      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", default: "1h", description: "Time range" },
          granularity: { type: "string", enum: ["minute", "hour"], default: "minute" }
        }
      }.freeze

      def call(args)
        since = parse_since(args[:since] || '1h')
        granularity = args[:granularity] || 'minute'
        
        data = @project.traces
          .requests
          .where('started_at >= ?', since)
          .group("date_trunc('#{granularity}', started_at)")
          .count
          .sort
          .map { |bucket, count| { time: bucket, count: count } }
        
        {
          throughput: data,
          granularity: granularity,
          total: data.sum { |d| d[:count] }
        }
      end
      
      private
      
      def parse_since(value)
        case value
        when /^(\d+)h$/ then $1.to_i.hours.ago
        when /^(\d+)d$/ then $1.to_i.days.ago
        else 1.hour.ago
        end
      end
    end
  end
end

# app/services/mcp/tools/pulse_errors.rb

module Mcp
  module Tools
    class PulseErrors < Base
      DESCRIPTION = "Get requests that resulted in errors (5xx status or exceptions)."
      
      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", default: "1h", description: "Time range" },
          limit: { type: "integer", default: 20 }
        }
      }.freeze

      def call(args)
        since = parse_since(args[:since] || '1h')
        limit = args[:limit] || 20
        
        traces = @project.traces
          .where('started_at >= ?', since)
          .where(error: true)
          .order(started_at: :desc)
          .limit(limit)
        
        {
          error_traces: traces.map { |t|
            {
              id: t.id,
              name: t.name,
              error_class: t.error_class,
              error_message: t.error_message&.truncate(200),
              started_at: t.started_at,
              duration_ms: t.duration_ms
            }
          },
          count: traces.size
        }
      end
      
      private
      
      def parse_since(value)
        case value
        when /^(\d+)h$/ then $1.to_i.hours.ago
        when /^(\d+)d$/ then $1.to_i.days.ago
        else 1.hour.ago
        end
      end
    end
  end
end

# app/services/mcp/tools/pulse_trace.rb

module Mcp
  module Tools
    class PulseTrace < Base
      DESCRIPTION = "Get detailed trace with all spans (waterfall view). " \
        "Use to analyze a specific request's performance breakdown."
      
      SCHEMA = {
        type: "object",
        properties: {
          trace_id: { type: "string", description: "Trace ID" }
        },
        required: ["trace_id"]
      }.freeze

      def call(args)
        trace = @project.traces.find_by!(trace_id: args[:trace_id])
        
        {
          trace: {
            id: trace.id,
            trace_id: trace.trace_id,
            name: trace.name,
            kind: trace.kind,
            started_at: trace.started_at,
            duration_ms: trace.duration_ms,
            status: trace.status,
            error: trace.error,
            error_class: trace.error_class,
            error_message: trace.error_message,
            db_duration_ms: trace.db_duration_ms,
            view_duration_ms: trace.view_duration_ms,
            external_duration_ms: trace.external_duration_ms
          },
          spans: trace.waterfall
        }
      rescue ActiveRecord::RecordNotFound
        { error: "Trace not found" }
      end
    end
  end
end

# app/services/mcp/tools/pulse_endpoints.rb

module Mcp
  module Tools
    class PulseEndpoints < Base
      DESCRIPTION = "Get performance stats by endpoint (controller/action). " \
        "Shows which endpoints are slowest or most called."
      
      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", default: "1h" },
          sort_by: { type: "string", enum: ["count", "avg_duration", "p95"], default: "count" },
          limit: { type: "integer", default: 20 }
        }
      }.freeze

      def call(args)
        since = parse_since(args[:since] || '1h')
        limit = args[:limit] || 20
        
        endpoints = @project.traces
          .requests
          .where('started_at >= ?', since)
          .where.not(duration_ms: nil)
          .group(:name)
          .select(
            'name',
            'COUNT(*) as count',
            'AVG(duration_ms) as avg_duration',
            'MAX(duration_ms) as max_duration',
            'SUM(CASE WHEN error THEN 1 ELSE 0 END) as error_count'
          )
        
        sorted = case args[:sort_by]
          when 'avg_duration' then endpoints.order('avg_duration DESC')
          when 'p95' then endpoints.order('max_duration DESC')
          else endpoints.order('count DESC')
        end
        
        {
          endpoints: sorted.limit(limit).map { |e|
            {
              name: e.name,
              count: e.count,
              avg_duration_ms: e.avg_duration.round(2),
              max_duration_ms: e.max_duration,
              error_count: e.error_count,
              error_rate: (e.error_count.to_f / e.count * 100).round(2)
            }
          }
        }
      end
      
      private
      
      def parse_since(value)
        case value
        when /^(\d+)h$/ then $1.to_i.hours.ago
        when /^(\d+)d$/ then $1.to_i.days.ago
        else 1.hour.ago
        end
      end
    end
  end
end

# app/services/mcp/tools/pulse_metrics.rb

module Mcp
  module Tools
    class PulseMetrics < Base
      DESCRIPTION = "Get custom metrics. List available metrics or query a specific one."
      
      SCHEMA = {
        type: "object",
        properties: {
          name: { type: "string", description: "Metric name (omit to list all)" },
          since: { type: "string", default: "1h" }
        }
      }.freeze

      def call(args)
        if args[:name]
          metric = @project.metrics.find_by!(name: args[:name])
          since = parse_since(args[:since] || '1h')
          
          {
            metric: {
              name: metric.name,
              kind: metric.kind,
              unit: metric.unit
            },
            stats: metric.stats(since: since)
          }
        else
          {
            metrics: @project.metrics.map { |m|
              { name: m.name, kind: m.kind, unit: m.unit }
            }
          }
        end
      rescue ActiveRecord::RecordNotFound
        { error: "Metric not found" }
      end
      
      private
      
      def parse_since(value)
        case value
        when /^(\d+)h$/ then $1.to_i.hours.ago
        when /^(\d+)d$/ then $1.to_i.days.ago
        else 1.hour.ago
        end
      end
    end
  end
end
```

---

## Routes

```ruby
# config/routes.rb

Rails.application.routes.draw do
  # API
  namespace :api do
    namespace :v1 do
      # Traces
      post 'traces', to: 'traces#create'
      post 'traces/batch', to: 'traces#batch'
      get 'traces', to: 'traces#index'
      get 'traces/:id', to: 'traces#show'
      
      # Spans (for adding to existing trace)
      post 'traces/:trace_id/spans', to: 'spans#create'
      
      # Metrics
      post 'metrics', to: 'metrics#create'
      post 'metrics/batch', to: 'metrics#batch'
      get 'metrics', to: 'metrics#index'
      get 'metrics/:name/stats', to: 'metrics#stats'
      
      # Overview
      get 'overview', to: 'metrics#overview'
    end
  end
  
  # MCP Server
  namespace :mcp do
    get 'tools', to: 'tools#index'
    post 'tools/:name', to: 'tools#call'
    post 'rpc', to: 'tools#rpc'
  end
  
  # SSO from Platform
  get 'auth/sso', to: 'sso#callback'
  
  # Dashboard
  namespace :dashboard do
    root to: 'overview#show'
    
    get 'overview', to: 'overview#show'
    
    resources :requests, only: [:index, :show]
    resources :traces, only: [:index, :show]
    resources :metrics, only: [:index, :show]
    
    get 'endpoints', to: 'endpoints#index'
  end
  
  # Health
  get 'up', to: ->(_) { [200, {}, ['ok']] }
  
  # WebSocket
  mount ActionCable.server => '/cable'
  
  root 'dashboard/overview#show'
end
```

---

## Dashboard Views

```erb
<%# app/views/layouts/dashboard.html.erb %>

<!DOCTYPE html>
<html lang="en" class="h-full bg-stone-50">
<head>
  <title>Pulse - APM</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <%= csrf_meta_tags %>
  <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
  <%= javascript_include_tag "application", "data-turbo-track": "reload", type: "module" %>
</head>
<body class="h-full font-sans antialiased text-stone-900">
  <div class="min-h-full">
    <header class="border-b border-stone-200 bg-white">
      <div class="mx-auto max-w-7xl px-6">
        <div class="flex h-14 items-center justify-between">
          <div class="flex items-center gap-4">
            <a href="https://brainzlab.ai/dashboard" class="text-stone-400 hover:text-stone-600">
              ← Brainz Lab
            </a>
            <span class="text-stone-300">|</span>
            <%= link_to dashboard_root_path, class: "flex items-center gap-2 font-semibold" do %>
              <span class="text-green-500">💓</span>
              <span>Pulse</span>
            <% end %>
          </div>
          
          <nav class="flex items-center gap-6 text-sm">
            <%= link_to "Overview", dashboard_overview_path, class: "text-stone-600 hover:text-stone-900" %>
            <%= link_to "Requests", dashboard_requests_path, class: "text-stone-600 hover:text-stone-900" %>
            <%= link_to "Endpoints", dashboard_endpoints_path, class: "text-stone-600 hover:text-stone-900" %>
            <%= link_to "Metrics", dashboard_metrics_path, class: "text-stone-600 hover:text-stone-900" %>
          </nav>
        </div>
      </div>
    </header>
    
    <main class="mx-auto max-w-7xl px-6 py-8">
      <%= yield %>
    </main>
  </div>
</body>
</html>

<%# app/views/dashboard/overview/show.html.erb %>

<div class="space-y-8" data-controller="live-metrics" data-live-metrics-project-value="<%= @project.id %>">
  
  <!-- Time range selector -->
  <div class="flex justify-between items-center">
    <h1 class="text-2xl font-bold">Overview</h1>
    <div class="flex gap-2">
      <% %w[1h 6h 24h 7d].each do |range| %>
        <%= link_to range, dashboard_overview_path(since: range),
            class: "px-3 py-1.5 text-sm font-medium rounded-lg #{params[:since] == range || (params[:since].nil? && range == '1h') ? 'bg-stone-900 text-white' : 'bg-white border border-stone-200 text-stone-600 hover:bg-stone-50'}" %>
      <% end %>
    </div>
  </div>
  
  <!-- Key metrics cards -->
  <div class="grid grid-cols-4 gap-4">
    <!-- Apdex -->
    <div class="bg-white rounded-xl border border-stone-200 p-5">
      <div class="flex items-center justify-between">
        <span class="text-sm text-stone-500">Apdex</span>
        <span class="apdex-indicator apdex-<%= apdex_status(@overview[:apdex]) %>"></span>
      </div>
      <p class="text-3xl font-bold mt-2"><%= @overview[:apdex] %></p>
      <p class="text-xs text-stone-400 mt-1">T = <%= @project.apdex_t %>s</p>
    </div>
    
    <!-- Throughput -->
    <div class="bg-white rounded-xl border border-stone-200 p-5">
      <span class="text-sm text-stone-500">Throughput</span>
      <p class="text-3xl font-bold mt-2"><%= number_with_delimiter(@overview[:rpm]) %></p>
      <p class="text-xs text-stone-400 mt-1">requests/min</p>
    </div>
    
    <!-- Response Time -->
    <div class="bg-white rounded-xl border border-stone-200 p-5">
      <span class="text-sm text-stone-500">Response Time</span>
      <p class="text-3xl font-bold mt-2"><%= @overview[:avg_duration]&.round(0) || '—' %></p>
      <p class="text-xs text-stone-400 mt-1">
        P95: <%= @overview[:p95_duration]&.round(0) %>ms
        P99: <%= @overview[:p99_duration]&.round(0) %>ms
      </p>
    </div>
    
    <!-- Error Rate -->
    <div class="bg-white rounded-xl border border-stone-200 p-5">
      <div class="flex items-center justify-between">
        <span class="text-sm text-stone-500">Error Rate</span>
        <% if @overview[:error_rate] > 1 %>
          <span class="w-2 h-2 rounded-full bg-red-500"></span>
        <% end %>
      </div>
      <p class="text-3xl font-bold mt-2 <%= 'text-red-600' if @overview[:error_rate] > 1 %>">
        <%= @overview[:error_rate] %>%
      </p>
      <p class="text-xs text-stone-400 mt-1"><%= @overview[:error_count] %> errors</p>
    </div>
  </div>
  
  <!-- Charts -->
  <div class="grid grid-cols-2 gap-6">
    <!-- Throughput chart -->
    <div class="bg-white rounded-xl border border-stone-200 p-5">
      <h3 class="font-medium mb-4">Throughput</h3>
      <div class="h-48" data-controller="chart" data-chart-type-value="line" data-chart-data-value="<%= @throughput_data.to_json %>">
        <canvas></canvas>
      </div>
    </div>
    
    <!-- Response time chart -->
    <div class="bg-white rounded-xl border border-stone-200 p-5">
      <h3 class="font-medium mb-4">Response Time</h3>
      <div class="h-48" data-controller="chart" data-chart-type-value="line" data-chart-data-value="<%= @response_time_data.to_json %>">
        <canvas></canvas>
      </div>
    </div>
  </div>
  
  <!-- Slow requests -->
  <div class="bg-white rounded-xl border border-stone-200">
    <div class="p-5 border-b border-stone-100 flex justify-between items-center">
      <h3 class="font-medium">Slow Requests</h3>
      <%= link_to "View all →", dashboard_requests_path(slow: true), class: "text-sm text-stone-500 hover:text-stone-700" %>
    </div>
    
    <div class="divide-y divide-stone-100">
      <% @slow_requests.each do |trace| %>
        <%= link_to dashboard_trace_path(trace), class: "flex items-center gap-4 p-4 hover:bg-stone-50" do %>
          <span class="text-lg font-bold text-stone-300 w-16 text-right"><%= trace.duration_ms.round(0) %><span class="text-xs">ms</span></span>
          <div class="flex-1 min-w-0">
            <p class="font-medium truncate"><%= trace.name %></p>
            <p class="text-sm text-stone-500"><%= time_ago_in_words(trace.started_at) %> ago</p>
          </div>
          <div class="text-right text-sm">
            <p class="text-stone-500">DB: <%= trace.db_duration_ms.round(0) %>ms</p>
            <p class="text-stone-500">View: <%= trace.view_duration_ms.round(0) %>ms</p>
          </div>
        <% end %>
      <% end %>
      
      <% if @slow_requests.empty? %>
        <div class="p-8 text-center text-stone-400">
          No slow requests 🎉
        </div>
      <% end %>
    </div>
  </div>
</div>

<%# app/views/dashboard/traces/show.html.erb %>

<div class="space-y-6">
  <!-- Header -->
  <div>
    <%= link_to '← Back', dashboard_requests_path, class: 'text-stone-400 hover:text-stone-600' %>
    <h1 class="text-2xl font-bold mt-2"><%= @trace.name %></h1>
    <p class="text-stone-500 mt-1"><%= @trace.started_at.strftime('%b %d, %Y at %H:%M:%S') %></p>
  </div>
  
  <!-- Summary cards -->
  <div class="grid grid-cols-5 gap-4">
    <div class="bg-white rounded-lg border border-stone-200 p-4">
      <p class="text-sm text-stone-500">Total Duration</p>
      <p class="text-2xl font-bold"><%= @trace.duration_ms.round(0) %><span class="text-sm">ms</span></p>
    </div>
    <div class="bg-white rounded-lg border border-stone-200 p-4">
      <p class="text-sm text-stone-500">Database</p>
      <p class="text-2xl font-bold"><%= @trace.db_duration_ms.round(0) %><span class="text-sm">ms</span></p>
    </div>
    <div class="bg-white rounded-lg border border-stone-200 p-4">
      <p class="text-sm text-stone-500">View</p>
      <p class="text-2xl font-bold"><%= @trace.view_duration_ms.round(0) %><span class="text-sm">ms</span></p>
    </div>
    <div class="bg-white rounded-lg border border-stone-200 p-4">
      <p class="text-sm text-stone-500">External</p>
      <p class="text-2xl font-bold"><%= @trace.external_duration_ms.round(0) %><span class="text-sm">ms</span></p>
    </div>
    <div class="bg-white rounded-lg border border-stone-200 p-4">
      <p class="text-sm text-stone-500">Status</p>
      <p class="text-2xl font-bold <%= @trace.error ? 'text-red-600' : 'text-green-600' %>">
        <%= @trace.status || (@trace.error ? 'Error' : 'OK') %>
      </p>
    </div>
  </div>
  
  <!-- Waterfall -->
  <div class="bg-white rounded-xl border border-stone-200">
    <div class="p-5 border-b border-stone-100">
      <h3 class="font-medium">Trace Waterfall</h3>
    </div>
    
    <div class="p-4">
      <div class="relative" data-controller="waterfall" data-waterfall-total-value="<%= @trace.duration_ms %>">
        <% @trace.waterfall.each do |span| %>
          <div class="flex items-center gap-2 py-1.5 hover:bg-stone-50 rounded">
            <!-- Timing -->
            <span class="text-xs text-stone-400 w-16 text-right font-mono">
              +<%= span[:offset_ms].round(0) %>ms
            </span>
            
            <!-- Bar -->
            <div class="flex-1 h-6 relative">
              <div class="absolute h-full rounded span-<%= span[:kind] %>"
                   style="left: <%= (span[:offset_ms] / @trace.duration_ms * 100).round(2) %>%; width: <%= [(span[:duration_ms] / @trace.duration_ms * 100).round(2), 0.5].max %>%">
              </div>
            </div>
            
            <!-- Name -->
            <div class="w-64 truncate">
              <span class="kind-badge kind-<%= span[:kind] %>"><%= span[:kind] %></span>
              <span class="text-sm ml-2"><%= span[:name] %></span>
            </div>
            
            <!-- Duration -->
            <span class="text-sm text-stone-500 w-20 text-right">
              <%= span[:duration_ms]&.round(1) %>ms
            </span>
          </div>
        <% end %>
      </div>
    </div>
  </div>
  
  <% if @trace.error %>
    <!-- Error details -->
    <div class="bg-red-50 rounded-xl border border-red-200 p-5">
      <h3 class="font-medium text-red-800">Error</h3>
      <p class="text-red-700 font-mono mt-2"><%= @trace.error_class %></p>
      <p class="text-red-600 mt-1"><%= @trace.error_message %></p>
    </div>
  <% end %>
  
  <!-- Context -->
  <div class="bg-white rounded-xl border border-stone-200 p-5">
    <h3 class="font-medium mb-4">Context</h3>
    <dl class="grid grid-cols-2 gap-4 text-sm">
      <div>
        <dt class="text-stone-500">Request ID</dt>
        <dd class="font-mono"><%= @trace.request_id %></dd>
      </div>
      <div>
        <dt class="text-stone-500">Commit</dt>
        <dd class="font-mono"><%= @trace.commit %></dd>
      </div>
      <div>
        <dt class="text-stone-500">Host</dt>
        <dd><%= @trace.host %></dd>
      </div>
      <div>
        <dt class="text-stone-500">User</dt>
        <dd><%= @trace.user_id || '—' %></dd>
      </div>
    </dl>
  </div>
</div>
```

---

## Tailwind Styles

```css
/* app/assets/stylesheets/application.tailwind.css */

@tailwind base;
@tailwind components;
@tailwind utilities;

@layer components {
  /* Apdex indicators */
  .apdex-indicator {
    @apply w-3 h-3 rounded-full;
  }
  .apdex-excellent { @apply bg-green-500; }
  .apdex-good { @apply bg-green-400; }
  .apdex-fair { @apply bg-yellow-400; }
  .apdex-poor { @apply bg-orange-500; }
  .apdex-unacceptable { @apply bg-red-500; }
  
  /* Span kind badges */
  .kind-badge {
    @apply inline-block px-1.5 py-0.5 text-xs font-medium rounded uppercase;
  }
  .kind-db { @apply bg-purple-100 text-purple-700; }
  .kind-http { @apply bg-blue-100 text-blue-700; }
  .kind-cache { @apply bg-green-100 text-green-700; }
  .kind-render { @apply bg-orange-100 text-orange-700; }
  .kind-custom { @apply bg-stone-100 text-stone-700; }
  
  /* Span bars in waterfall */
  .span-db { @apply bg-purple-400; }
  .span-http { @apply bg-blue-400; }
  .span-cache { @apply bg-green-400; }
  .span-render { @apply bg-orange-400; }
  .span-custom { @apply bg-stone-400; }
}
```

---

## SDK Integration (Pulse module)

```ruby
# lib/brainzlab/pulse.rb (in brainzlab-sdk gem)

module BrainzLab
  module Pulse
    class << self
      # Start a new trace
      def trace(name, kind: 'custom', **attributes, &block)
        return yield unless BrainzLab.config.pulse_enabled?
        
        trace = Trace.new(name: name, kind: kind, **attributes)
        
        begin
          result = yield trace
          trace.finish!
          result
        rescue => e
          trace.finish!(error: e)
          raise
        end
      end
      
      # Track a custom metric
      def track(name, value, unit: nil, tags: {})
        return unless BrainzLab.config.pulse_enabled?
        
        client.post('/api/v1/metrics', {
          name: name,
          value: value,
          unit: unit,
          tags: tags,
          timestamp: Time.now.utc.iso8601(3)
        })
      end
      
      # Measure a block of code
      def measure(name, tags: {}, &block)
        return yield unless BrainzLab.config.pulse_enabled?
        
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(2)
        
        track(name, duration, unit: 'ms', tags: tags)
        
        result
      end
      
      def reset!
        @client = nil
      end
      
      private
      
      def client
        @client ||= Client.new(base_url: BrainzLab.config.pulse_url)
      end
    end
    
    class Trace
      attr_reader :trace_id, :name, :kind, :started_at
      
      def initialize(name:, kind: 'custom', **attributes)
        @trace_id = SecureRandom.hex(16)
        @name = name
        @kind = kind
        @attributes = attributes
        @started_at = Time.now.utc
        @spans = []
        @current_span = nil
      end
      
      # Add a span to the trace
      def span(name, kind: 'custom', **data)
        span = Span.new(trace: self, name: name, kind: kind, data: data)
        
        begin
          result = yield span if block_given?
          span.finish!
          @spans << span.to_h
          result
        rescue => e
          span.finish!(error: e)
          @spans << span.to_h
          raise
        end
      end
      
      def finish!(error: nil)
        @ended_at = Time.now.utc
        @error = error
        
        send_to_api!
      end
      
      private
      
      def send_to_api!
        payload = {
          trace_id: @trace_id,
          name: @name,
          kind: @kind,
          started_at: @started_at.iso8601(3),
          ended_at: @ended_at.iso8601(3),
          duration_ms: ((@ended_at - @started_at) * 1000).round(2),
          environment: BrainzLab.config.environment,
          commit: BrainzLab.config.commit,
          host: BrainzLab.config.host,
          spans: @spans
        }.merge(@attributes)
        
        if @error
          payload[:error] = true
          payload[:error_class] = @error.class.name
          payload[:error_message] = @error.message
        end
        
        # Add context
        if (user = Context.current_user)
          payload[:user_id] = user[:id]
        end
        
        if (request = Context.current_request)
          payload[:request_id] = request[:id]
          payload[:request_method] = request[:method]
          payload[:request_path] = request[:path]
        end
        
        BrainzLab::Pulse.send(:client).post('/api/v1/traces', payload, async: true)
      end
    end
    
    class Span
      def initialize(trace:, name:, kind:, data:)
        @trace = trace
        @span_id = SecureRandom.hex(8)
        @name = name
        @kind = kind
        @data = data
        @started_at = Time.now.utc
      end
      
      def finish!(error: nil)
        @ended_at = Time.now.utc
        @error = error
      end
      
      def to_h
        h = {
          span_id: @span_id,
          name: @name,
          kind: @kind,
          started_at: @started_at.iso8601(3),
          ended_at: @ended_at.iso8601(3),
          duration_ms: ((@ended_at - @started_at) * 1000).round(2),
          data: @data
        }
        
        if @error
          h[:error] = true
          h[:error_class] = @error.class.name
          h[:error_message] = @error.message
        end
        
        h
      end
    end
  end
end
```

---

## Docker Compose

```yaml
# docker-compose.yml

services:
  web:
    build: .
    ports: ["3000:3000"]
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/pulse
      REDIS_URL: redis://redis:6379/0
      PLATFORM_URL: http://platform:3000
      SERVICE_TOKEN: dev-service-token
      SECRET_KEY_BASE: dev-secret
    depends_on: [db, redis]
    volumes: [".:/rails"]

  db:
    image: timescale/timescaledb:latest-pg16
    environment:
      POSTGRES_DB: pulse
      POSTGRES_PASSWORD: postgres
    volumes: [pgdata:/var/lib/postgresql/data]

  redis:
    image: redis:7-alpine

volumes:
  pgdata:
```

---

## MCP Tools Summary

| Tool | Description |
|------|-------------|
| `pulse_overview` | Health metrics: Apdex, throughput, P95, error rate |
| `pulse_slow_requests` | Find slowest requests |
| `pulse_throughput` | Requests per minute over time |
| `pulse_errors` | Requests that errored |
| `pulse_trace` | Detailed trace with span waterfall |
| `pulse_endpoints` | Performance by endpoint |
| `pulse_metrics` | Custom metrics |

---

## AI Conversation Examples

```
User: How is the app performing?

AI: [calls pulse_overview()]
    Your app is healthy:
    - Apdex: 0.94 (Good)
    - Throughput: 1,234 rpm
    - Avg response: 145ms (P95: 320ms)
    - Error rate: 0.2%

User: What's causing slow requests?

AI: [calls pulse_slow_requests(threshold_ms: 500)]
    Found 5 requests over 500ms:
    1. GET /api/reports - 2,340ms (DB: 1,890ms)
    2. POST /orders - 1,120ms (External: 890ms)
    3. GET /users/:id - 890ms (DB: 650ms)
    
    The reports endpoint has heavy database time.
    Let me check that trace...

    [calls pulse_trace(trace_id: "xxx")]
    
    The trace shows 12 SQL queries, 8 of which are N+1 queries 
    on the `report_items` table. Consider using `includes(:items)`.

User: Which endpoints are busiest?

AI: [calls pulse_endpoints(sort_by: "count")]
    Top endpoints by traffic:
    1. GET /api/health - 45,000 req (avg: 2ms)
    2. GET /api/users - 12,340 req (avg: 45ms)
    3. POST /api/events - 8,900 req (avg: 23ms)
```

---

## Success Criteria

1. ✅ Traces ingested via API with spans
2. ✅ Apdex calculation
3. ✅ Response time percentiles (P50, P95, P99)
4. ✅ Throughput tracking
5. ✅ Waterfall view for traces
6. ✅ Custom metrics
7. ✅ TimescaleDB for efficient time-series
8. ✅ MCP tools for AI
9. ✅ SDK integration with Rails

---

**Domain:** pulse.brainzlab.ai

**Tagline:** *"Your app's vital signs"*
