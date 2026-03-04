# Pulse APM Enhancements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Upgrade Pulse to compete with existing APM tools (Datadog, New Relic) by fixing performance bottlenecks, adding cross-service correlation, new visualizations, and missing features — all within the BrainzLab ecosystem.

**Architecture:** Extend Pulse's existing Rails 8 + TimescaleDB + Hotwire stack. Add new models (Deploy, SLO, SavedView), new MCP tools, cross-service API calls to Recall/Reflex/Sentinel, and enhanced Stimulus controllers for flame charts, heatmaps, and service maps. All changes use PostgreSQL-native functions to replace in-memory calculations.

**Tech Stack:** Rails 8, PostgreSQL + TimescaleDB, Hotwire (Turbo + Stimulus), Chart.js + D3.js (flame chart), Tailwind CSS, Solid Queue, ActionCable

---

## Workstream A: Performance Fixes & Database Optimization

### Task A1: Fix percentile calculation bottleneck in Project#overview

**Files:**
- Modify: `app/models/project.rb:64-66`
- Test: `test/models/project_test.rb`

**Step 1: Write the failing test**

```ruby
# In test/models/project_test.rb
test "overview uses SQL percentiles instead of pluck" do
  project = create_test_project
  50.times { |i| create_test_trace(project, duration_ms: i * 10.0, kind: "request") }

  # Should NOT load all durations into memory
  result = project.overview(since: 1.hour.ago)
  assert_not_nil result[:p95_duration]
  assert_not_nil result[:p99_duration]
  assert result[:p95_duration] > result[:avg_duration]
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/edixonhernandez/runmyprocess/brainzlab/pulse && bin/rails test test/models/project_test.rb -v`

**Step 3: Replace in-memory percentile with SQL**

Replace lines 64-66 in `app/models/project.rb`:

```ruby
# OLD (loads ALL durations into memory):
# durations = traces_scope.where.not(duration_ms: nil).order(:duration_ms).pluck(:duration_ms)
# p95_duration = durations.any? ? durations[(durations.length * 0.95).to_i] : nil
# p99_duration = durations.any? ? durations[(durations.length * 0.99).to_i] : nil

# NEW (single SQL query):
percentiles = traces_scope.where.not(duration_ms: nil).pick(
  Arel.sql("PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms)"),
  Arel.sql("PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms)")
)
p95_duration = percentiles&.first&.round(2)
p99_duration = percentiles&.last&.round(2)
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/edixonhernandez/runmyprocess/brainzlab/pulse && bin/rails test test/models/project_test.rb -v`

**Step 5: Commit**

```bash
git add app/models/project.rb test/models/project_test.rb
git commit -m "perf: replace in-memory percentile with SQL PERCENTILE_CONT in Project#overview"
```

---

### Task A2: Fix percentile calculation in AlertEvaluator

**Files:**
- Modify: `app/services/alert_evaluator.rb:78-82`
- Test: `test/services/alert_evaluator_test.rb`

**Step 1: Write failing test**

```ruby
test "calculate_percentile uses SQL percentile function" do
  project = create_test_project
  100.times { |i| create_test_trace(project, duration_ms: i.to_f, kind: "request") }
  evaluator = AlertEvaluator.new(project: project)

  rule = project.alert_rules.create!(
    name: "P95 test", metric_type: "p95", operator: "gt",
    threshold: 999, window_minutes: 60, severity: "warning"
  )
  evaluator.evaluate_rule!(rule)
  assert_equal "ok", rule.reload.status
end
```

**Step 2: Run test**

**Step 3: Fix the calculation**

Replace `calculate_percentile` method in `alert_evaluator.rb`:

```ruby
def calculate_percentile(scope, p)
  scope.where.not(duration_ms: nil).pick(
    Arel.sql("PERCENTILE_CONT(#{p}) WITHIN GROUP (ORDER BY duration_ms)")
  )
end
```

**Step 4: Run tests, Step 5: Commit**

---

### Task A3: Fix in-memory grouping in MetricsAggregator

**Files:**
- Modify: `app/services/metrics_aggregator.rb:141-184` (aggregate_external_http! and aggregate_cache!)
- Test: `test/services/metrics_aggregator_test.rb`

**Step 1: Write test for SQL-based external HTTP aggregation**

```ruby
test "aggregate_external_http uses SQL grouping not Ruby" do
  project = create_test_project
  trace = create_test_trace(project)
  create_test_span(trace, kind: "http", duration_ms: 100, data: { "host" => "api.stripe.com" })
  create_test_span(trace, kind: "http", duration_ms: 200, data: { "host" => "api.stripe.com" })

  aggregator = MetricsAggregator.new(project: project)
  aggregator.aggregate_minute!(trace.started_at)

  agg = project.aggregated_metrics.find_by(name: "external_http_duration")
  assert_not_nil agg
  assert_equal 2, agg.count
end
```

**Step 2: Run test**

**Step 3: Replace Ruby group_by with SQL**

```ruby
def aggregate_external_http!(bucket)
  spans = @project.spans
    .joins(:trace)
    .where(traces: { started_at: bucket...bucket + 1.minute })
    .where(kind: "http")

  return if spans.empty?

  # Use SQL to extract host from JSONB and group
  hosts = spans.select("data->>'host' as host").distinct.pluck(Arel.sql("data->>'host'"))

  hosts.compact.reject { |h| h == "unknown" }.each do |host|
    host_spans = spans.where("data->>'host' = ?", host)
    durations = host_spans.where.not(duration_ms: nil).pluck(:duration_ms).sort
    next if durations.empty?

    error_count = host_spans.where(error: true).count
    total = host_spans.count

    create_or_update_aggregate(
      name: "external_http_duration", bucket: bucket, granularity: "minute",
      values: durations, dimensions: { host: host }
    )
    create_or_update_aggregate(
      name: "external_http_count", bucket: bucket, granularity: "minute",
      values: [total], dimensions: { host: host }
    )
    create_or_update_aggregate(
      name: "external_http_error_rate", bucket: bucket, granularity: "minute",
      values: [(error_count.to_f / total * 100).round(2)], dimensions: { host: host }
    )
  end
end
```

**Step 4: Run tests, Step 5: Commit**

---

### Task A4: Add missing database indexes

**Files:**
- Create: `db/migrate/TIMESTAMP_add_performance_indexes.rb`

**Step 1: Generate migration**

```bash
bin/rails generate migration AddPerformanceIndexes
```

**Step 2: Write migration**

```ruby
class AddPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    # For error list views
    add_index :traces, [:project_id, :error, :started_at],
      name: "idx_traces_errors_lookup",
      where: "error = true"

    # For slow span analysis
    add_index :spans, [:project_id, :kind, :duration_ms],
      name: "idx_spans_kind_duration",
      order: { duration_ms: :desc }

    # For aggregated metric time-series dashboard queries
    add_index :aggregated_metrics, [:project_id, :name, :granularity, :bucket],
      name: "idx_agg_metrics_timeseries",
      order: { bucket: :desc }

    # For metric point cleanup and time-range queries
    add_index :metric_points, [:project_id, :timestamp],
      name: "idx_metric_points_cleanup",
      order: { timestamp: :desc }
  end
end
```

**Step 3: Run migration**

```bash
bin/rails db:migrate
```

**Step 4: Commit**

---

### Task A5: Fix endpoint groups to use SQL aggregation

**Files:**
- Modify: `app/controllers/dashboard/endpoints_controller.rb:74-106`
- Test: `test/controllers/dashboard/endpoints_controller_test.rb`

Replace `fetch_endpoint_groups` with SQL-based approach:

```ruby
def fetch_endpoint_groups
  scope = current_project.traces
    .requests
    .where("started_at >= ?", @since)
    .where.not(duration_ms: nil)
    .where.not(name: nil)

  # Extract prefix using SQL
  scope.select(
    "CONCAT('/', split_part(split_part(name, ' ', 2), '/', 2), '/', split_part(split_part(name, ' ', 2), '/', 3)) as prefix_name",
    "COUNT(*) as count",
    "AVG(duration_ms) as avg_duration",
    "MAX(duration_ms) as max_duration",
    "PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95_duration",
    "PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms) as p99_duration",
    "SUM(CASE WHEN error THEN 1 ELSE 0 END) as error_count",
    "(SUM(CASE WHEN error THEN 1 ELSE 0 END)::float / COUNT(*) * 100) as error_rate",
    "COUNT(DISTINCT name) as endpoint_count"
  )
  .group("prefix_name")
  .having("prefix_name IS NOT NULL AND prefix_name != '//'")
  .order("count DESC")
  .limit(50)
end
```

---

### Task A6: Add pagination to Queries and Endpoints views

**Files:**
- Modify: `app/controllers/dashboard/queries_controller.rb`
- Modify: `app/controllers/dashboard/endpoints_controller.rb`
- Modify: `app/views/dashboard/endpoints/index.html.erb`

Add `pagy` to endpoints index (already included via BaseController):

```ruby
# In endpoints_controller.rb#index, after fetch:
@pagy, @endpoints = pagy_array(@endpoints, items: 25) if @endpoints.is_a?(Array)
```

---

## Workstream B: New Models & Migrations

### Task B1: Create Deploy model for deployment markers

**Files:**
- Create: `db/migrate/TIMESTAMP_create_deploys.rb`
- Create: `app/models/deploy.rb`
- Test: `test/models/deploy_test.rb`

**Migration:**

```ruby
class CreateDeploys < ActiveRecord::Migration[8.1]
  def change
    create_table :deploys, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :version, null: false
      t.string :commit_sha
      t.string :deployed_by
      t.string :environment
      t.text :description
      t.jsonb :metadata, default: {}
      t.datetime :deployed_at, null: false
      t.timestamps
    end

    add_index :deploys, [:project_id, :deployed_at], order: { deployed_at: :desc }
  end
end
```

**Model:**

```ruby
class Deploy < ApplicationRecord
  belongs_to :project
  validates :version, :deployed_at, presence: true
  scope :recent, -> { order(deployed_at: :desc) }
  scope :since, ->(time) { where("deployed_at >= ?", time) }
end
```

---

### Task B2: Create ServiceLevelObjective model for SLO tracking

**Files:**
- Create: `db/migrate/TIMESTAMP_create_service_level_objectives.rb`
- Create: `app/models/service_level_objective.rb`
- Create: `app/services/slo_calculator.rb`
- Test: `test/models/service_level_objective_test.rb`
- Test: `test/services/slo_calculator_test.rb`

**Migration:**

```ruby
class CreateServiceLevelObjectives < ActiveRecord::Migration[8.1]
  def change
    create_table :service_level_objectives, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.text :description
      t.string :target_metric, null: false    # apdex, error_rate, p95, p99, availability
      t.string :operator, null: false          # lt, lte, gt, gte
      t.float :threshold, null: false          # target value (e.g., 99.9 for availability)
      t.integer :window_days, default: 30      # rolling window
      t.string :endpoint                        # optional: specific endpoint
      t.float :current_value                    # last computed value
      t.float :error_budget_remaining           # percentage remaining
      t.float :burn_rate                        # current burn rate
      t.datetime :last_calculated_at
      t.boolean :enabled, default: true
      t.timestamps
    end

    add_index :service_level_objectives, [:project_id, :enabled]
  end
end
```

**Service (SloCalculator):**

```ruby
class SloCalculator
  def initialize(slo:)
    @slo = slo
    @project = slo.project
  end

  def calculate!
    current = compute_current_value
    budget = compute_error_budget(current)
    burn = compute_burn_rate

    @slo.update!(
      current_value: current,
      error_budget_remaining: budget,
      burn_rate: burn,
      last_calculated_at: Time.current
    )
  end

  private

  def compute_current_value
    since = @slo.window_days.days.ago
    scope = @project.traces.where("started_at >= ?", since).where(kind: "request")
    scope = scope.where(name: @slo.endpoint) if @slo.endpoint.present?

    case @slo.target_metric
    when "error_rate"
      total = scope.count
      return 0.0 if total == 0
      (scope.where(error: true).count.to_f / total * 100).round(4)
    when "p95"
      scope.where.not(duration_ms: nil).pick(
        Arel.sql("PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms)")
      )&.round(2)
    when "p99"
      scope.where.not(duration_ms: nil).pick(
        Arel.sql("PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms)")
      )&.round(2)
    when "apdex"
      ApdexCalculator.calculate(traces: scope, threshold: @project.apdex_t)
    when "availability"
      total = scope.count
      return 100.0 if total == 0
      successful = scope.where(error: false).count
      (successful.to_f / total * 100).round(4)
    end
  end

  def compute_error_budget(current_value)
    return 100.0 unless current_value
    case @slo.operator
    when "lte"
      remaining = @slo.threshold - current_value
      (remaining / @slo.threshold * 100).round(2).clamp(0, 100)
    when "gte"
      return 100.0 if current_value >= @slo.threshold
      gap = @slo.threshold - current_value
      (100.0 - (gap / @slo.threshold * 100)).round(2).clamp(0, 100)
    else 100.0
    end
  end

  def compute_burn_rate
    one_hour = compute_value_for_range(1.hour.ago)
    return 0.0 unless one_hour
    expected_budget_per_hour = 100.0 / (@slo.window_days * 24)
    return 0.0 if expected_budget_per_hour == 0
    actual_burn = case @slo.operator
    when "lte" then one_hour > @slo.threshold ? 1.0 : 0.0
    when "gte" then one_hour < @slo.threshold ? 1.0 : 0.0
    else 0.0
    end
    (actual_burn / expected_budget_per_hour).round(2)
  end

  def compute_value_for_range(since)
    scope = @project.traces.where("started_at >= ?", since).where(kind: "request")
    scope = scope.where(name: @slo.endpoint) if @slo.endpoint.present?
    total = scope.count
    return nil if total == 0
    case @slo.target_metric
    when "error_rate"
      (scope.where(error: true).count.to_f / total * 100).round(4)
    when "availability"
      (scope.where(error: false).count.to_f / total * 100).round(4)
    else nil
    end
  end
end
```

---

### Task B3: Create SavedView model

**Files:**
- Create: `db/migrate/TIMESTAMP_create_saved_views.rb`
- Create: `app/models/saved_view.rb`

**Migration:**

```ruby
class CreateSavedViews < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_views, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :project, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :view_type, null: false  # requests, endpoints, queries, overview
      t.jsonb :filters, default: {}     # serialized filter state
      t.boolean :pinned, default: false
      t.timestamps
    end

    add_index :saved_views, [:project_id, :view_type]
  end
end
```

---

## Workstream C: UI Enhancements & New Views

### Task C1: Add advanced filters to Requests view

**Files:**
- Modify: `app/controllers/dashboard/requests_controller.rb`
- Modify: `app/views/dashboard/requests/index.html.erb`

**Controller changes:**

```ruby
module Dashboard
  class RequestsController < BaseController
    def index
      @since = parse_since(params[:since])
      scope = current_project.traces.requests.where("started_at >= ?", @since)

      scope = scope.slow(params[:threshold]&.to_i || 500) if params[:slow].present?
      scope = scope.errors if params[:errors].present?
      scope = scope.where(controller: params[:controller]) if params[:controller].present?
      scope = scope.where(request_method: params[:method]) if params[:method].present?
      scope = scope.where("duration_ms >= ?", params[:min_duration].to_f) if params[:min_duration].present?
      scope = scope.where("duration_ms <= ?", params[:max_duration].to_f) if params[:max_duration].present?
      scope = scope.where(host: params[:host]) if params[:host].present?
      scope = scope.where(environment: params[:environment]) if params[:environment].present?
      scope = scope.order(started_at: :desc)

      @pagy, @traces = pagy(scope)

      # For filter dropdowns
      @controllers = current_project.traces.requests
        .where("started_at >= ?", @since)
        .distinct.pluck(:controller).compact.sort
      @hosts = current_project.traces.requests
        .where("started_at >= ?", @since)
        .distinct.pluck(:host).compact.sort
    end

    def show
      @trace = current_project.traces.includes(:spans).find_by!(trace_id: params[:id])
    end

    private

    def parse_since(value)
      case value
      when "6h" then 6.hours.ago
      when "24h" then 24.hours.ago
      when "7d" then 7.days.ago
      else 1.hour.ago
      end
    end
  end
end
```

**View: Add filter bar above table with time range, controller, method, host, duration range, environment selectors.**

---

### Task C2: Add comparison mode to Overview

**Files:**
- Modify: `app/controllers/dashboard/overview_controller.rb`
- Modify: `app/views/dashboard/overview/show.html.erb`
- Create: `app/javascript/controllers/comparison_controller.js`

**Controller: Add comparison data**

```ruby
def show
  @since = parse_since(params[:since])
  @overview = current_project.overview(since: @since)
  @throughput_data = throughput_data
  @response_time_data = response_time_data
  @slow_requests = current_project.traces.requests.slow(500)
    .where("started_at >= ?", @since).order(duration_ms: :desc).limit(5)

  # Comparison: previous equivalent period
  range_duration = Time.current - @since
  @comparison = current_project.overview(since: @since - range_duration)
  @deltas = compute_deltas(@overview, @comparison)
end

private

def compute_deltas(current, previous)
  {}.tap do |d|
    [:apdex, :rpm, :avg_duration, :p95_duration, :error_rate].each do |metric|
      curr = current[metric].to_f
      prev = previous[metric].to_f
      d[metric] = prev > 0 ? ((curr - prev) / prev * 100).round(1) : 0
    end
  end
end
```

**View: Show delta indicators (arrows + percentage) next to each KPI card.**

---

### Task C3: Create Service Map view

**Files:**
- Create: `app/controllers/dashboard/service_map_controller.rb`
- Create: `app/views/dashboard/service_map/show.html.erb`
- Create: `app/javascript/controllers/service_map_controller.js`
- Modify: `config/routes.rb` (add route)
- Modify: `app/views/layouts/dashboard.html.erb` (add nav link)

**Controller:**

```ruby
module Dashboard
  class ServiceMapController < BaseController
    def show
      @since = parse_since(params[:since] || "1h")
      @nodes, @edges = build_service_graph
    end

    private

    def build_service_graph
      nodes = {}
      edges = []

      # Current service
      nodes["pulse"] = { name: current_project.name || "This App", type: "app", rpm: 0, avg_ms: 0 }

      # External HTTP calls from spans
      http_stats = current_project.spans
        .joins(:trace)
        .where(traces: { started_at: @since.. })
        .where(kind: "http")
        .where.not("data->>'host' IS NULL")
        .group("data->>'host'")
        .select(
          "data->>'host' as host",
          "COUNT(*) as call_count",
          "AVG(duration_ms) as avg_duration",
          "SUM(CASE WHEN spans.error THEN 1 ELSE 0 END) as error_count"
        )

      http_stats.each do |stat|
        host = stat.host
        next if host.blank?
        nodes[host] = { name: host, type: "external", rpm: stat.call_count, avg_ms: stat.avg_duration&.round(1) }
        edges << { from: "pulse", to: host, calls: stat.call_count, avg_ms: stat.avg_duration&.round(1),
                   error_rate: stat.call_count > 0 ? (stat.error_count.to_f / stat.call_count * 100).round(1) : 0 }
      end

      # Database calls
      db_count = current_project.spans.joins(:trace)
        .where(traces: { started_at: @since.. }).where("kind LIKE 'db%'").count
      if db_count > 0
        avg_db = current_project.spans.joins(:trace)
          .where(traces: { started_at: @since.. }).where("kind LIKE 'db%'").average(:duration_ms)
        nodes["database"] = { name: "Database", type: "database", rpm: db_count, avg_ms: avg_db&.round(1) }
        edges << { from: "pulse", to: "database", calls: db_count, avg_ms: avg_db&.round(1), error_rate: 0 }
      end

      # Cache calls
      cache_count = current_project.spans.joins(:trace)
        .where(traces: { started_at: @since.. }).where("kind LIKE 'cache%'").count
      if cache_count > 0
        nodes["cache"] = { name: "Cache (Redis)", type: "cache", rpm: cache_count }
        edges << { from: "pulse", to: "cache", calls: cache_count, avg_ms: 0, error_rate: 0 }
      end

      [nodes, edges]
    end

    def parse_since(value)
      case value
      when "6h" then 6.hours.ago
      when "24h" then 24.hours.ago
      when "7d" then 7.days.ago
      else 1.hour.ago
      end
    end
  end
end
```

**Route:** `resource :service_map, only: [:show], controller: "service_map"`

**Stimulus Controller:** D3.js force-directed graph rendering with nodes colored by type and edges sized by throughput.

---

### Task C4: Add Flame Chart toggle to trace detail

**Files:**
- Modify: `app/views/dashboard/requests/show.html.erb`
- Create: `app/javascript/controllers/flame_chart_controller.js`

**Stimulus controller** that takes span data as JSON value, renders a flame chart where:
- X axis = real time (started_at offset from trace start)
- Width = span duration
- Y axis = span depth (parent_span_id hierarchy)
- Color = span kind (db=blue, http=green, cache=amber, render=purple)

Toggle between "Waterfall" and "Flame Chart" views with a tab control.

---

### Task C5: Add latency heatmap to Overview

**Files:**
- Create: `app/javascript/controllers/heatmap_controller.js`
- Modify: `app/controllers/dashboard/overview_controller.rb`
- Modify: `app/views/dashboard/overview/show.html.erb`

**Controller: Add heatmap data endpoint**

Bucket traces by time (x) and duration range (y) to create a 2D histogram:

```ruby
def heatmap_data
  buckets = [0, 50, 100, 200, 500, 1000, 2000, 5000, Float::INFINITY]
  data = current_project.traces.requests
    .where("started_at >= ?", @since)
    .where.not(duration_ms: nil)
    .group("date_trunc('minute', started_at)")
    .select(
      "date_trunc('minute', started_at) as bucket_time",
      *buckets.each_cons(2).map { |low, high|
        if high == Float::INFINITY
          "COUNT(*) FILTER (WHERE duration_ms >= #{low}) as bucket_#{low}_plus"
        else
          "COUNT(*) FILTER (WHERE duration_ms >= #{low} AND duration_ms < #{high}) as bucket_#{low}_#{high}"
        end
      }
    )
  data.map { |row| row.attributes.except("id") }
end
```

**Stimulus controller:** Canvas-based heatmap with color intensity proportional to count per cell.

---

### Task C6: Deployment markers on charts

**Files:**
- Create: `app/controllers/api/v1/deploys_controller.rb`
- Modify: `app/controllers/dashboard/overview_controller.rb`
- Modify: `app/javascript/controllers/chart_controller.js`
- Modify: `config/routes.rb`

**API endpoint:**

```ruby
module Api
  module V1
    class DeploysController < BaseController
      def create
        deploy = @current_project.deploys.create!(
          version: params[:version],
          commit_sha: params[:commit_sha],
          deployed_by: params[:deployed_by],
          environment: params[:environment] || @current_project.environment,
          description: params[:description],
          deployed_at: params[:deployed_at] || Time.current
        )
        render json: { deploy: deploy.as_json }, status: :created
      end
    end
  end
end
```

**Chart.js plugin:** Draw vertical dashed lines at deploy timestamps with version label tooltip.

---

### Task C7: Endpoint drill-down improvements

**Files:**
- Modify: `app/views/dashboard/endpoints/show.html.erb`
- Modify: `app/controllers/dashboard/endpoints_controller.rb`

Add to endpoint detail view:
- Breakdown by span kind (pie chart: DB vs HTTP vs render vs cache)
- P50/P95/P99 sparklines
- Error rate mini-chart
- Trend indicator (up/down arrow) comparing to previous period

---

## Workstream D: Cross-Service Correlation

### Task D1: Trace-to-Logs link (Recall integration)

**Files:**
- Create: `app/services/recall_client.rb`
- Modify: `app/views/dashboard/requests/show.html.erb`
- Modify: `config/routes.rb`

**Service:**

```ruby
class RecallClient
  BASE_URL = ENV.fetch("BRAINZLAB_RECALL_URL", "http://localhost:4001")

  def self.logs_url_for(request_id:, since:, until_time:)
    params = URI.encode_www_form(
      request_id: request_id,
      since: since.iso8601,
      until: until_time.iso8601
    )
    "#{external_url}/dashboard/logs?#{params}"
  end

  def self.fetch_logs(request_id:, api_key:, limit: 20)
    uri = URI("#{BASE_URL}/api/v1/logs?request_id=#{request_id}&limit=#{limit}")
    req = Net::HTTP::Get.new(uri)
    req["X-API-Key"] = api_key
    response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
    JSON.parse(response.body) if response.code == "200"
  rescue => e
    Rails.logger.warn("RecallClient error: #{e.message}")
    nil
  end

  def self.external_url
    ENV.fetch("BRAINZLAB_RECALL_EXTERNAL_URL", "http://recall.brainzlab.local")
  end
end
```

**View:** Add "View Logs in Recall" button linking to Recall filtered by request_id.

---

### Task D2: Trace-to-Errors link (Reflex integration)

**Files:**
- Create: `app/services/reflex_client.rb`
- Modify: `app/views/dashboard/requests/show.html.erb`

**Service:**

```ruby
class ReflexClient
  BASE_URL = ENV.fetch("BRAINZLAB_REFLEX_URL", "http://localhost:4002")

  def self.error_url_for(error_class:, since:)
    params = URI.encode_www_form(error_class: error_class, since: since.iso8601)
    "#{external_url}/dashboard/errors?#{params}"
  end

  def self.fetch_error_group(error_class:, api_key:)
    uri = URI("#{BASE_URL}/api/v1/errors?error_class=#{CGI.escape(error_class)}&limit=1")
    req = Net::HTTP::Get.new(uri)
    req["X-API-Key"] = api_key
    response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
    JSON.parse(response.body) if response.code == "200"
  rescue => e
    Rails.logger.warn("ReflexClient error: #{e.message}")
    nil
  end

  def self.external_url
    ENV.fetch("BRAINZLAB_REFLEX_EXTERNAL_URL", "http://reflex.brainzlab.local")
  end
end
```

**View:** On error traces, show "View in Reflex" button with error group info panel.

---

### Task D3: Infrastructure overlay (Sentinel integration)

**Files:**
- Create: `app/services/sentinel_client.rb`
- Modify: `app/views/dashboard/overview/show.html.erb`

**Service:**

```ruby
class SentinelClient
  BASE_URL = ENV.fetch("BRAINZLAB_SENTINEL_URL", "http://localhost:4014")

  def self.host_metrics(host:, since:, api_key:)
    params = URI.encode_www_form(host: host, since: since.iso8601)
    uri = URI("#{BASE_URL}/api/v1/metrics?#{params}")
    req = Net::HTTP::Get.new(uri)
    req["X-API-Key"] = api_key
    response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
    JSON.parse(response.body) if response.code == "200"
  rescue => e
    Rails.logger.warn("SentinelClient error: #{e.message}")
    nil
  end

  def self.external_url
    ENV.fetch("BRAINZLAB_SENTINEL_EXTERNAL_URL", "http://sentinel.brainzlab.local")
  end
end
```

---

## Workstream E: New MCP Tools

### Task E1: pulse_service_map tool

**Files:**
- Create: `app/services/mcp/tools/pulse_service_map.rb`
- Modify: `app/services/mcp/server.rb`
- Test: `test/services/mcp/tools_test.rb`

```ruby
module Mcp
  module Tools
    class PulseServiceMap < Base
      DESCRIPTION = "Get service dependency map showing external calls, databases, and caches with latency and throughput"
      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", description: "Time range (e.g., '1h', '24h', '7d')", default: "1h" }
        }
      }

      def call(args)
        since = parse_since(args[:since])
        nodes = {}
        edges = []

        nodes[@project.name || "app"] = { type: "app" }

        # External HTTP dependencies
        @project.spans.joins(:trace)
          .where(traces: { started_at: since.. })
          .where(kind: "http")
          .where.not("spans.data->>'host' IS NULL")
          .group("spans.data->>'host'")
          .select("spans.data->>'host' as host, COUNT(*) as calls, AVG(spans.duration_ms) as avg_ms,
                   SUM(CASE WHEN spans.error THEN 1 ELSE 0 END) as errors")
          .each do |row|
            nodes[row.host] = { type: "external_service" }
            edges << { from: @project.name, to: row.host, calls: row.calls,
                       avg_ms: row.avg_ms&.round(1), error_rate: (row.errors.to_f / row.calls * 100).round(1) }
          end

        # DB stats
        db = @project.spans.joins(:trace).where(traces: { started_at: since.. })
          .where("spans.kind LIKE 'db%'")
          .pick(Arel.sql("COUNT(*)"), Arel.sql("AVG(spans.duration_ms)"))
        if db[0]&.positive?
          nodes["database"] = { type: "database" }
          edges << { from: @project.name, to: "database", calls: db[0], avg_ms: db[1]&.round(1) }
        end

        { nodes: nodes, edges: edges }
      end
    end
  end
end
```

---

### Task E2: pulse_compare tool

**Files:**
- Create: `app/services/mcp/tools/pulse_compare.rb`
- Modify: `app/services/mcp/server.rb`

```ruby
module Mcp
  module Tools
    class PulseCompare < Base
      DESCRIPTION = "Compare performance metrics between two time periods to detect regressions or improvements"
      SCHEMA = {
        type: "object",
        properties: {
          period_a: { type: "string", description: "First period (e.g., '1h')", default: "1h" },
          period_b: { type: "string", description: "Second period for comparison (e.g., '24h')" },
          endpoint: { type: "string", description: "Optional: specific endpoint to compare" }
        },
        required: ["period_a", "period_b"]
      }

      def call(args)
        since_a = parse_since(args[:period_a])
        since_b = parse_since(args[:period_b])

        metrics_a = compute_metrics(since_a, args[:endpoint])
        metrics_b = compute_metrics(since_b, args[:endpoint])

        deltas = {}
        metrics_a.each do |key, val_a|
          val_b = metrics_b[key]
          next unless val_a && val_b && val_b != 0
          deltas[key] = { current: val_a, previous: val_b,
                          change_pct: ((val_a - val_b).to_f / val_b * 100).round(2) }
        end

        { period_a: args[:period_a], period_b: args[:period_b], metrics: deltas }
      end

      private

      def compute_metrics(since, endpoint = nil)
        scope = @project.traces.where("started_at >= ?", since).where(kind: "request")
        scope = scope.where(name: endpoint) if endpoint.present?
        total = scope.count
        return {} if total == 0

        stats = scope.where.not(duration_ms: nil).pick(
          Arel.sql("AVG(duration_ms)"),
          Arel.sql("PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms)"),
          Arel.sql("PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY duration_ms)")
        )

        error_count = scope.where(error: true).count
        {
          throughput: total,
          avg_duration: stats[0]&.round(2),
          p95: stats[1]&.round(2),
          p99: stats[2]&.round(2),
          error_rate: (error_count.to_f / total * 100).round(2)
        }
      end
    end
  end
end
```

---

### Task E3: pulse_root_cause tool

**Files:**
- Create: `app/services/mcp/tools/pulse_root_cause.rb`
- Modify: `app/services/mcp/server.rb`

```ruby
module Mcp
  module Tools
    class PulseRootCause < Base
      DESCRIPTION = "Automated root cause analysis: identifies top affected endpoints, slowest spans, problematic queries for a given symptom"
      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", default: "1h" },
          symptom: { type: "string", enum: ["high_latency", "high_errors", "low_apdex"],
                     description: "The symptom to investigate" }
        },
        required: ["symptom"]
      }

      def call(args)
        since = parse_since(args[:since])
        scope = @project.traces.where("started_at >= ?", since).where(kind: "request")

        case args[:symptom]
        when "high_latency"
          analyze_latency(scope, since)
        when "high_errors"
          analyze_errors(scope, since)
        when "low_apdex"
          analyze_apdex(scope, since)
        end
      end

      private

      def analyze_latency(scope, since)
        # Top slow endpoints
        slow_endpoints = scope.where.not(duration_ms: nil)
          .group(:name).select("name, AVG(duration_ms) as avg_ms, COUNT(*) as cnt")
          .order("avg_ms DESC").limit(5).map { |r| { endpoint: r.name, avg_ms: r.avg_ms.round(1), count: r.cnt } }

        # Slowest spans
        slow_spans = @project.spans.joins(:trace).where(traces: { started_at: since.. })
          .where.not(duration_ms: nil).order(duration_ms: :desc).limit(10)
          .pluck(:name, :kind, :duration_ms)
          .map { |n, k, d| { name: n, kind: k, duration_ms: d } }

        { symptom: "high_latency", top_slow_endpoints: slow_endpoints, slowest_spans: slow_spans }
      end

      def analyze_errors(scope, since)
        # Top error endpoints
        error_endpoints = scope.where(error: true)
          .group(:name).select("name, COUNT(*) as cnt")
          .order("cnt DESC").limit(5).map { |r| { endpoint: r.name, error_count: r.cnt } }

        # Top error classes
        error_classes = scope.where(error: true).where.not(error_class: nil)
          .group(:error_class).order("count_all DESC").limit(5).count
          .map { |cls, cnt| { error_class: cls, count: cnt } }

        { symptom: "high_errors", top_error_endpoints: error_endpoints, top_error_classes: error_classes }
      end

      def analyze_apdex(scope, since)
        threshold_ms = @project.apdex_t * 1000
        frustrated = scope.where("duration_ms > ?", threshold_ms * 4)
          .group(:name).select("name, COUNT(*) as cnt, AVG(duration_ms) as avg_ms")
          .order("cnt DESC").limit(5)
          .map { |r| { endpoint: r.name, frustrated_count: r.cnt, avg_ms: r.avg_ms.round(1) } }

        { symptom: "low_apdex", threshold_ms: threshold_ms, top_frustrated_endpoints: frustrated }
      end
    end
  end
end
```

---

### Task E4: pulse_slo_status and pulse_deploy_impact tools

**Files:**
- Create: `app/services/mcp/tools/pulse_slo_status.rb`
- Create: `app/services/mcp/tools/pulse_deploy_impact.rb`
- Modify: `app/services/mcp/server.rb`

Register all new tools in `Mcp::Server::TOOLS`:

```ruby
TOOLS = {
  "pulse_overview" => Tools::PulseOverview,
  "pulse_slow_requests" => Tools::PulseSlowRequests,
  "pulse_throughput" => Tools::PulseThroughput,
  "pulse_errors" => Tools::PulseErrors,
  "pulse_trace" => Tools::PulseTrace,
  "pulse_endpoints" => Tools::PulseEndpoints,
  "pulse_metrics" => Tools::PulseMetrics,
  "pulse_service_map" => Tools::PulseServiceMap,
  "pulse_compare" => Tools::PulseCompare,
  "pulse_root_cause" => Tools::PulseRootCause,
  "pulse_slo_status" => Tools::PulseSloStatus,
  "pulse_deploy_impact" => Tools::PulseDeployImpact
}.freeze
```

---

## Workstream F: SLO Dashboard & Deploys Dashboard

### Task F1: SLO dashboard views

**Files:**
- Create: `app/controllers/dashboard/slos_controller.rb`
- Create: `app/views/dashboard/slos/index.html.erb`
- Create: `app/views/dashboard/slos/_form.html.erb`
- Create: `app/views/dashboard/slos/show.html.erb`
- Modify: `config/routes.rb`
- Modify: `app/views/layouts/dashboard.html.erb` (nav link)

Dashboard showing:
- List of SLOs with status badges (meeting/at risk/breached)
- Error budget remaining (progress bar)
- Burn rate indicator
- Click-through to detail with time-series of SLI value vs target

---

### Task F2: Deploys dashboard integration

**Files:**
- Create: `app/controllers/dashboard/deploys_controller.rb`
- Create: `app/views/dashboard/deploys/index.html.erb`
- Modify: `config/routes.rb`

List of recent deploys with:
- Version, commit, who deployed, when
- Auto-comparison: metrics before vs after deploy (1h window)
- Impact badge: improved/degraded/neutral

---

## Workstream G: Security & Quality Review

### Task G1: Security audit of new API endpoints

Review all new controllers for:
- SQL injection in Arel.sql() calls (ensure no user input interpolation)
- CSRF protection on API endpoints
- Authorization: all endpoints require valid API key
- Rate limiting considerations
- Input validation on Deploy and SLO creation

### Task G2: Fix inline styles inconsistency

**Files:** All views in `app/views/dashboard/`

Replace hardcoded hex colors with Tailwind utility classes:
- `style="color: #1A1A1A"` → `class="pulse-text"`
- `style="background: #FFFFFE"` → `class="pulse-card"`
- `style="border: 1px solid #E8E5E0"` → `class="pulse-card-inner-border"`

Ensure dark mode works consistently across all views.

---

## Task Dependencies

```
A1 ──┐
A2 ──┤
A3 ──┼── A4 (indexes) ── All workstreams can proceed
A5 ──┤
A6 ──┘

B1 ── C6 (deploy markers), E4 (deploy impact tool), F2 (deploys dashboard)
B2 ── E4 (SLO status tool), F1 (SLO dashboard)
B3 ── (independent)

C1-C7 ── (independent of each other, depend on A4)
D1-D3 ── (independent of each other)
E1-E4 ── (depend on B1, B2 for deploy/SLO tools)
F1-F2 ── (depend on B1, B2)
G1-G2 ── (run after all others)
```

## Agent Assignment

| Workstream | Agent | Focus |
|-----------|-------|-------|
| A (Performance) | dev-perf | SQL optimization, indexes, eager loading |
| B (Models) | dev-models | Migrations, models, services |
| C (UI) | dev-ui | Views, Stimulus controllers, Chart.js |
| D (Integration) | dev-integration | Cross-service clients, view links |
| E (MCP Tools) | dev-mcp | New MCP tools |
| F (Dashboards) | dev-dashboard | SLO + Deploy dashboard pages |
| G (Security) | security-review | Audit after implementation |
