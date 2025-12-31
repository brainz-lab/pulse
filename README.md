# Pulse

APM and performance monitoring for Rails apps.

[![CI](https://github.com/brainz-lab/pulse/actions/workflows/ci.yml/badge.svg)](https://github.com/brainz-lab/pulse/actions/workflows/ci.yml)
[![CodeQL](https://github.com/brainz-lab/pulse/actions/workflows/codeql.yml/badge.svg)](https://github.com/brainz-lab/pulse/actions/workflows/codeql.yml)
[![codecov](https://codecov.io/gh/brainz-lab/pulse/graph/badge.svg)](https://codecov.io/gh/brainz-lab/pulse)
[![Docker](https://github.com/brainz-lab/pulse/actions/workflows/docker.yml/badge.svg)](https://github.com/brainz-lab/pulse/actions/workflows/docker.yml)
[![Docker Hub](https://img.shields.io/docker/v/brainzllc/pulse?label=Docker%20Hub)](https://hub.docker.com/r/brainzllc/pulse)
[![Docs](https://img.shields.io/badge/docs-brainzlab.ai-orange)](https://docs.brainzlab.ai/products/pulse/overview)
[![License: OSAaSy](https://img.shields.io/badge/License-OSAaSy-blue.svg)](LICENSE)

## Overview

Pulse monitors your application's vital signs - response times, throughput, database queries, and more.

- **Request Tracing** - Full request lifecycle with span waterfall
- **Apdex Score** - Application performance index (0-1)
- **Slow Query Detection** - Find N+1s and slow database calls
- **Real-time Metrics** - Live dashboard with WebSocket updates
- **Custom Metrics** - Track business metrics (gauges, counters, histograms)
- **Alerting** - Get notified when performance degrades
- **MCP Integration** - AI-powered performance analysis

## Quick Start

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

## Tech Stack

- **Ruby** 3.4.7
- **Rails** 8.1
- **PostgreSQL** 16 with TimescaleDB (time-series)
- **Redis** 7
- **Hotwire** (Turbo + Stimulus)
- **Tailwind CSS**
- **Solid Queue** / **Solid Cache** / **Solid Cable**

## Apdex Score

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

## API Endpoints

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

### MCP
- `GET /mcp/tools` - List MCP tools
- `POST /mcp/tools/:name` - Call MCP tool
- `POST /mcp/rpc` - JSON-RPC endpoint

## MCP Tools

| Tool | Description |
|------|-------------|
| `pulse_overview` | Health metrics: Apdex, throughput, P95, error rate |
| `pulse_slow_requests` | Find slowest requests |
| `pulse_throughput` | Requests per minute over time |
| `pulse_errors` | Requests that errored |
| `pulse_trace` | Detailed trace with span waterfall |
| `pulse_endpoints` | Performance by endpoint |
| `pulse_metrics` | Custom metrics |

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection | Yes |
| `REDIS_URL` | Redis connection | Yes |
| `RAILS_MASTER_KEY` | Rails credentials | Yes |
| `BRAINZLAB_PLATFORM_URL` | Platform URL for auth | Yes |
| `SERVICE_KEY` | Internal service key | Yes |

## Trace Payload Format

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
      "started_at": "...",
      "ended_at": "...",
      "duration_ms": 12.5,
      "data": {
        "sql": "SELECT * FROM users LIMIT 20",
        "table": "users"
      }
    },
    {
      "span_id": "span_2",
      "name": "render users/index",
      "kind": "render",
      "duration_ms": 45.2
    }
  ]
}
```

## Alerting

Create alert rules based on:

- **Apdex** drops below threshold
- **Error rate** exceeds percentage
- **P95 latency** exceeds duration
- **Throughput** drops below RPM
- **Custom metrics** cross thresholds

Notify via:
- Slack
- Email
- Webhooks
- PagerDuty

## Testing

```bash
bin/rails test              # Unit tests
bin/rails test:system       # System tests
bin/rubocop                 # Linting
```

## Documentation

Full documentation: [docs.brainzlab.ai/products/pulse](https://docs.brainzlab.ai/products/pulse/overview)

## Related

- [brainzlab-ruby](https://github.com/brainz-lab/brainzlab-ruby) - Ruby SDK
- [Recall](https://github.com/brainz-lab/recall) - Structured logging
- [Reflex](https://github.com/brainz-lab/reflex) - Error tracking
- [Stack](https://github.com/brainz-lab/stack) - Self-hosted deployment

## Contributors

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

Thanks to all our contributors! See [all-contributors](https://allcontributors.org) for how to add yourself.


## License

MIT
