# Seed data for Pulse development

puts "Creating project..."
project = Project.find_or_create_by!(platform_project_id: 'dev_project') do |p|
  p.name = 'Demo App'
  p.environment = 'development'
  p.apdex_t = 0.5
end

puts "Creating traces..."

# Sample endpoints with realistic patterns
endpoints = [
  { method: 'GET', path: '/api/users', controller: 'Api::UsersController', action: 'index', avg_ms: 45 },
  { method: 'GET', path: '/api/users/:id', controller: 'Api::UsersController', action: 'show', avg_ms: 25 },
  { method: 'POST', path: '/api/users', controller: 'Api::UsersController', action: 'create', avg_ms: 120 },
  { method: 'GET', path: '/api/orders', controller: 'Api::OrdersController', action: 'index', avg_ms: 180 },
  { method: 'POST', path: '/api/orders', controller: 'Api::OrdersController', action: 'create', avg_ms: 350 },
  { method: 'GET', path: '/api/products', controller: 'Api::ProductsController', action: 'index', avg_ms: 85 },
  { method: 'GET', path: '/api/products/:id', controller: 'Api::ProductsController', action: 'show', avg_ms: 30 },
  { method: 'GET', path: '/dashboard', controller: 'DashboardController', action: 'index', avg_ms: 250 },
  { method: 'GET', path: '/reports', controller: 'ReportsController', action: 'index', avg_ms: 800 },
  { method: 'POST', path: '/api/checkout', controller: 'Api::CheckoutController', action: 'create', avg_ms: 450 }
]

# Job types
jobs = [
  { class: 'OrderProcessingJob', queue: 'default', avg_ms: 2500 },
  { class: 'EmailDeliveryJob', queue: 'mailers', avg_ms: 800 },
  { class: 'ReportGeneratorJob', queue: 'low', avg_ms: 15000 },
  { class: 'CacheWarmupJob', queue: 'low', avg_ms: 5000 }
]

# Generate traces for the last 24 hours
now = Time.current
traces_created = 0

24.times do |hours_ago|
  time_base = now - hours_ago.hours

  # More traffic during business hours
  requests_this_hour = case hours_ago % 24
  when 9..17 then rand(80..150)  # Business hours
  when 18..21 then rand(40..80)  # Evening
  else rand(10..30)              # Night
  end

  requests_this_hour.times do |i|
    endpoint = endpoints.sample
    started_at = time_base - rand(0..59).minutes - rand(0..59).seconds

    # Add variance to duration (some fast, some slow)
    variance = rand(0.5..2.0)
    duration_ms = (endpoint[:avg_ms] * variance).round(2)

    # Occasionally make requests slow
    if rand < 0.05
      duration_ms *= rand(3..8)
    end

    # Occasionally add errors
    has_error = rand < 0.02
    status = has_error ? [ 500, 502, 503 ].sample : [ 200, 201, 204 ].sample

    trace = project.traces.create!(
      trace_id: SecureRandom.hex(16),
      name: "#{endpoint[:method]} #{endpoint[:path]}",
      kind: 'request',
      started_at: started_at,
      ended_at: started_at + (duration_ms / 1000.0).seconds,
      duration_ms: duration_ms,
      request_id: SecureRandom.uuid,
      request_method: endpoint[:method],
      request_path: endpoint[:path].gsub(':id', rand(1..1000).to_s),
      controller: endpoint[:controller],
      action: endpoint[:action],
      status: status,
      environment: 'production',
      commit: "abc#{rand(1000..9999)}",
      host: "web-#{rand(1..3)}",
      user_id: rand < 0.7 ? "user_#{rand(1..500)}" : nil,
      error: has_error,
      error_class: has_error ? [ 'ActiveRecord::RecordNotFound', 'ActionController::RoutingError', 'Redis::TimeoutError' ].sample : nil,
      error_message: has_error ? 'Something went wrong' : nil
    )

    # Add spans to trace
    remaining_ms = duration_ms
    span_started = started_at

    # DB spans
    db_queries = rand(1..5)
    db_queries.times do |j|
      query_ms = [ rand(1.0..20.0), remaining_ms * 0.3 ].min.round(2)
      remaining_ms -= query_ms

      trace.spans.create!(
        project: project,
        span_id: SecureRandom.hex(8),
        name: [ 'SELECT', 'INSERT', 'UPDATE' ].sample,
        kind: 'db',
        started_at: span_started,
        ended_at: span_started + (query_ms / 1000.0).seconds,
        duration_ms: query_ms,
        data: {
          sql: "SELECT * FROM #{[ 'users', 'orders', 'products', 'sessions' ].sample} WHERE id = ?",
          table: [ 'users', 'orders', 'products', 'sessions' ].sample,
          operation: [ 'SELECT', 'INSERT', 'UPDATE' ].sample
        }
      )
      span_started += (query_ms / 1000.0).seconds
    end

    # Cache spans
    if rand < 0.6
      cache_ms = rand(0.5..5.0).round(2)
      trace.spans.create!(
        project: project,
        span_id: SecureRandom.hex(8),
        name: 'Cache',
        kind: 'cache',
        started_at: span_started,
        ended_at: span_started + (cache_ms / 1000.0).seconds,
        duration_ms: cache_ms,
        data: {
          key: "cache:#{[ 'user', 'product', 'session' ].sample}:#{rand(1..1000)}",
          hit: rand < 0.8
        }
      )
      span_started += (cache_ms / 1000.0).seconds
    end

    # External HTTP spans
    if rand < 0.3
      http_ms = rand(20.0..200.0).round(2)
      trace.spans.create!(
        project: project,
        span_id: SecureRandom.hex(8),
        name: 'HTTP',
        kind: 'http',
        started_at: span_started,
        ended_at: span_started + (http_ms / 1000.0).seconds,
        duration_ms: http_ms,
        data: {
          method: 'POST',
          url: [ 'https://api.stripe.com/v1/charges', 'https://api.sendgrid.com/v3/mail/send', 'https://api.twilio.com/messages' ].sample,
          status: 200
        }
      )
      span_started += (http_ms / 1000.0).seconds
    end

    # View render span
    if endpoint[:controller].include?('Dashboard') || endpoint[:controller].include?('Reports')
      view_ms = rand(10.0..100.0).round(2)
      trace.spans.create!(
        project: project,
        span_id: SecureRandom.hex(8),
        name: 'Render',
        kind: 'render',
        started_at: span_started,
        ended_at: span_started + (view_ms / 1000.0).seconds,
        duration_ms: view_ms,
        data: {
          template: "#{endpoint[:action]}.html.erb",
          layout: 'application'
        }
      )
    end

    # Update trace metrics
    trace.update!(
      span_count: trace.spans.count,
      db_duration_ms: trace.spans.where(kind: 'db').sum(:duration_ms),
      view_duration_ms: trace.spans.where(kind: 'render').sum(:duration_ms),
      external_duration_ms: trace.spans.where(kind: 'http').sum(:duration_ms)
    )

    traces_created += 1
  end

  # Add some background jobs
  rand(5..15).times do
    job = jobs.sample
    started_at = time_base - rand(0..59).minutes
    duration_ms = (job[:avg_ms] * rand(0.5..2.0)).round(2)
    has_error = rand < 0.03

    trace = project.traces.create!(
      trace_id: SecureRandom.hex(16),
      name: job[:class],
      kind: 'job',
      started_at: started_at,
      ended_at: started_at + (duration_ms / 1000.0).seconds,
      duration_ms: duration_ms,
      job_class: job[:class],
      job_id: SecureRandom.uuid,
      queue: job[:queue],
      environment: 'production',
      commit: "abc#{rand(1000..9999)}",
      host: "worker-#{rand(1..2)}",
      error: has_error,
      error_class: has_error ? 'RuntimeError' : nil,
      error_message: has_error ? 'Job failed' : nil
    )
    traces_created += 1
  end

  print "."
end

puts "\nCreated #{traces_created} traces"

# Create some custom metrics
puts "Creating custom metrics..."

checkout_metric = project.metrics.find_or_create_by!(name: 'checkout.duration') do |m|
  m.kind = 'histogram'
  m.unit = 'ms'
  m.description = 'Checkout flow duration'
end

cache_hit_metric = project.metrics.find_or_create_by!(name: 'cache.hit_rate') do |m|
  m.kind = 'gauge'
  m.unit = 'percent'
  m.description = 'Cache hit rate'
end

queue_size_metric = project.metrics.find_or_create_by!(name: 'queue.size') do |m|
  m.kind = 'gauge'
  m.unit = 'count'
  m.description = 'Background job queue size'
end

# Add metric points
24.times do |hours_ago|
  time_base = now - hours_ago.hours

  6.times do |i|
    timestamp = time_base - (i * 10).minutes

    checkout_metric.record!(rand(200..800), timestamp: timestamp)
    cache_hit_metric.record!(rand(75..98), timestamp: timestamp)
    queue_size_metric.record!(rand(0..50), timestamp: timestamp)
  end
end

puts "Created #{project.metrics.count} metrics with #{MetricPoint.count} data points"

puts "\nSeed complete!"
puts "  Project: #{project.name}"
puts "  Traces: #{project.traces.count}"
puts "  Spans: #{project.spans.count}"
puts "  Metrics: #{project.metrics.count}"
