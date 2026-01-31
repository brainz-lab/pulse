# Pulse

APM and performance monitoring for Rails apps.

[![CI](https://github.com/brainz-lab/pulse/actions/workflows/ci.yml/badge.svg)](https://github.com/brainz-lab/pulse/actions/workflows/ci.yml)
[![CodeQL](https://github.com/brainz-lab/pulse/actions/workflows/codeql.yml/badge.svg)](https://github.com/brainz-lab/pulse/actions/workflows/codeql.yml)
[![codecov](https://codecov.io/gh/brainz-lab/pulse/graph/badge.svg)](https://codecov.io/gh/brainz-lab/pulse)
[![Docker](https://github.com/brainz-lab/pulse/actions/workflows/docker.yml/badge.svg)](https://github.com/brainz-lab/pulse/actions/workflows/docker.yml)
[![Docker Hub](https://img.shields.io/docker/v/brainzllc/pulse?label=Docker%20Hub)](https://hub.docker.com/r/brainzllc/pulse)
[![Docs](https://img.shields.io/badge/docs-brainzlab.ai-orange)](https://docs.brainzlab.ai/products/pulse/overview)
[![License: OSAaSy](https://img.shields.io/badge/License-OSAaSy-blue.svg)](LICENSE)

## Quick Start

```bash
# Install SDK
gem 'brainzlab'

# Configure
BrainzLab.configure { |c| c.pulse_key = ENV['PULSE_API_KEY'] }

# Automatic instrumentation starts immediately
# Track custom metrics
BrainzLab::Pulse.gauge("queue.size", Sidekiq::Queue.new.size)
```

## Installation

### With Docker

```bash
docker pull brainzllc/pulse:latest
# or
docker pull ghcr.io/brainz-lab/pulse:latest

docker run -d \
  -p 3000:3000 \
  -e DATABASE_URL=postgres://user:pass@host:5432/pulse \
  -e REDIS_URL=redis://host:6379/3 \
  -e RAILS_MASTER_KEY=your-master-key \
  brainzllc/pulse:latest
```

### Install SDK

```ruby
# Gemfile
gem 'brainzlab'
```

```ruby
# config/initializers/brainzlab.rb
BrainzLab.configure do |config|
  config.pulse_key = ENV['PULSE_API_KEY']
end
```

### Local Development

```bash
git clone https://github.com/brainz-lab/pulse.git
cd pulse
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server
```

## Configuration

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection | Yes |
| `REDIS_URL` | Redis connection | Yes |
| `RAILS_MASTER_KEY` | Rails credentials | Yes |
| `BRAINZLAB_PLATFORM_URL` | Platform URL for auth | Yes |
| `SERVICE_KEY` | Internal service key | Yes |

### Tech Stack

- **Ruby** 3.4.7 / **Rails** 8.1
- **PostgreSQL** 16 with TimescaleDB (time-series)
- **Redis** 7
- **Hotwire** (Turbo + Stimulus) / **Tailwind CSS**
- **Solid Queue** / **Solid Cache** / **Solid Cable**

## Usage

### Automatic Instrumentation

The SDK automatically instruments:
- HTTP requests (controller actions)
- Database queries (ActiveRecord)
- Cache operations (Rails.cache)
- Background jobs (Sidekiq, Solid Queue)
- External HTTP calls (Net::HTTP, Faraday)

### Custom Metrics

```ruby
# Gauges - current value
BrainzLab::Pulse.gauge("queue.size", Sidekiq::Queue.new.size)

# Counters - increment/decrement
BrainzLab::Pulse.increment("user.signups")
BrainzLab::Pulse.increment("orders.total", tags: { plan: "pro" })

# Histograms - distributions
BrainzLab::Pulse.histogram("payment.amount", order.total_cents / 100.0)

# Timing - measure duration
BrainzLab::Pulse.time("external.api") do
  ExternalApi.call
end
```

### Apdex Score

Application Performance Index measures user satisfaction:

| Response Time | Category | Score Weight |
|---------------|----------|--------------|
| <= T (500ms) | Satisfied | 1.0 |
| <= 4T (2s) | Tolerating | 0.5 |
| > 4T | Frustrated | 0.0 |

**Apdex = (Satisfied + Tolerating/2) / Total**

- **1.0** = Perfect
- **0.94+** = Excellent
- **0.85+** = Good
- **0.70+** = Fair
- **< 0.70** = Poor

### Trace Payload Format

```json
{
  "trace_id": "abc123...",
  "name": "GET /users",
  "kind": "request",
  "started_at": "2024-12-21T10:00:00Z",
  "ended_at": "2024-12-21T10:00:00.245Z",
  "duration_ms": 245,
  "request_method": "GET",
  "request_path": "/users",
  "controller": "UsersController",
  "action": "index",
  "status": 200,
  "environment": "production",
  "commit": "abc123",
  "host": "web-1",
  "spans": [
    {
      "span_id": "span_1",
      "name": "SELECT users",
      "kind": "db",
      "duration_ms": 12.5,
      "data": { "sql": "SELECT * FROM users LIMIT 20" }
    }
  ]
}
```

### Alerting

Create alert rules based on:
- **Apdex** drops below threshold
- **Error rate** exceeds percentage
- **P95 latency** exceeds duration
- **Throughput** drops below RPM
- **Custom metrics** cross thresholds

Notify via: Slack, Email, Webhooks, PagerDuty

## API Reference

### Ingest
- `POST /api/v1/traces` - Report single trace with spans
- `POST /api/v1/traces/batch` - Batch report
- `POST /api/v1/metrics` - Record custom metric
- `POST /api/v1/metrics/batch` - Batch metrics

### Query
- `GET /api/v1/overview` - Health overview (Apdex, throughput, P95)
- `GET /api/v1/traces` - List traces
- `GET /api/v1/traces/:id` - Get trace with span waterfall
- `GET /api/v1/metrics` - List custom metrics
- `GET /api/v1/metrics/:name/stats` - Metric statistics

### MCP Tools

| Tool | Description |
|------|-------------|
| `pulse_overview` | Health metrics: Apdex, throughput, P95, error rate |
| `pulse_slow_requests` | Find slowest requests |
| `pulse_throughput` | Requests per minute over time |
| `pulse_errors` | Requests that errored |
| `pulse_trace` | Detailed trace with span waterfall |
| `pulse_endpoints` | Performance by endpoint |
| `pulse_metrics` | Custom metrics |

Full documentation: [docs.brainzlab.ai/products/pulse](https://docs.brainzlab.ai/products/pulse/overview)

## Self-Hosting

### Docker Compose

```yaml
services:
  pulse:
    image: brainzllc/pulse:latest
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://user:pass@db:5432/pulse
      REDIS_URL: redis://redis:6379/3
      RAILS_MASTER_KEY: ${RAILS_MASTER_KEY}
      BRAINZLAB_PLATFORM_URL: http://platform:3000
    depends_on:
      - db
      - redis
```

### Testing

```bash
bin/rails test              # Unit tests
bin/rails test:system       # System tests
bin/rubocop                 # Linting
```

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for development setup and contribution guidelines.

## Related

- [brainzlab-ruby](https://github.com/brainz-lab/brainzlab-ruby) - Ruby SDK
- [Recall](https://github.com/brainz-lab/recall) - Structured logging
- [Reflex](https://github.com/brainz-lab/reflex) - Error tracking
- [Stack](https://github.com/brainz-lab/stack) - Self-hosted deployment

## License

MIT
