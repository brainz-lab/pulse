# CLAUDE.md

> **Secrets Reference**: See `../.secrets.md` (gitignored) for master keys, server access, and MCP tokens.

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: Pulse by Brainz Lab

APM and performance monitoring for Rails apps. Third product in the Brainz Lab suite.

**Domain**: pulse.brainzlab.ai

**Tagline**: "Your app's vital signs"

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          PULSE (Rails 8)                         │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │  Dashboard   │  │     API      │  │  MCP Server  │           │
│  │  (Hotwire)   │  │  (JSON API)  │  │   (Ruby)     │           │
│  │ /dashboard/* │  │  /api/v1/*   │  │   /mcp/*     │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                           │                  │                   │
│                           ▼                  ▼                   │
│              ┌─────────────────────────────────────┐            │
│              │   PostgreSQL + TimescaleDB          │            │
│              │   (for time-series data)            │            │
│              └─────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
                              ▲
            ┌─────────────────┴─────────────────┐
            │                                    │
    ┌───────┴───────┐                  ┌────────┴────────┐
    │  SDK (Gem)    │                  │   Claude/AI     │
    │ brainzlab-sdk │                  │  (Uses MCP)     │
    └───────────────┘                  └─────────────────┘
```

## Tech Stack

- **Backend**: Rails 8 API + Dashboard
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **Database**: PostgreSQL with TimescaleDB extension (for time-series)
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **WebSockets**: Solid Cable (real-time metrics)
- **MCP Server**: Ruby (integrated into Rails)

## Common Commands

```bash
# Development
bin/rails server
bin/rails console
bin/rails db:migrate

# Testing
bin/rails test
bin/rails test test/models/trace_test.rb  # single file

# Docker (from brainzlab root)
docker-compose --profile pulse up
docker-compose exec pulse bin/rails db:migrate

# Database
bin/rails db:create db:migrate
bin/rails db:seed

# Tailwind
bin/rails tailwindcss:build
```

## Key Models

- **Project**: Links to Platform via `platform_project_id`
- **Trace**: Request/job execution with timing (started_at, ended_at, duration_ms)
- **Span**: Child operations within a trace (db, http, cache, render)
- **Metric**: Custom metric definitions (gauge, counter, histogram)
- **MetricPoint**: Individual metric data points
- **AggregatedMetric**: Pre-computed aggregations for dashboards

## Trace Processing Flow

1. SDK/client sends trace to `POST /api/v1/traces`
2. `TraceProcessor` creates/updates trace with spans
3. Updates aggregate metrics (throughput, response times)
4. Broadcasts to `MetricsChannel` for real-time updates
5. `ApdexCalculator` computes application performance index

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

## API Endpoints

**Ingest**:
- `POST /api/v1/traces` - Ingest single trace with spans
- `POST /api/v1/traces/batch` - Batch ingest
- `POST /api/v1/metrics` - Record custom metric
- `POST /api/v1/metrics/batch` - Batch metrics

**Query**:
- `GET /api/v1/traces` - List traces
- `GET /api/v1/traces/:id` - Get trace with spans
- `GET /api/v1/overview` - Health overview
- `GET /api/v1/metrics` - List metrics
- `GET /api/v1/metrics/:name/stats` - Metric statistics

**MCP**:
- `GET /mcp/tools` - List tools
- `POST /mcp/tools/:name` - Call tool
- `POST /mcp/rpc` - JSON-RPC protocol

Authentication: `Authorization: Bearer <key>` or `X-API-Key: <key>`

## Trace Payload Format

```json
{
  "trace_id": "abc123...",
  "name": "GET /users",
  "kind": "request",
  "started_at": "2024-12-21T10:00:00Z",
  "ended_at": "2024-12-21T10:00:00.245Z",
  "request_method": "GET",
  "request_path": "/users",
  "controller": "UsersController",
  "action": "index",
  "status": 200,
  "environment": "production",
  "commit": "abc123",
  "host": "web-1",
  "user_id": "user_123",
  "spans": [
    {
      "span_id": "span_1",
      "name": "SELECT users",
      "kind": "db",
      "started_at": "...",
      "ended_at": "...",
      "duration_ms": 12.5,
      "data": { "sql": "SELECT * FROM users", "table": "users" }
    }
  ]
}
```

## Apdex Calculation

Application Performance Index (0.0 - 1.0):
- **Satisfied**: response <= T (default 0.5s)
- **Tolerating**: T < response <= 4T
- **Frustrated**: response > 4T

`Apdex = (Satisfied + Tolerating/2) / Total`

## Design Principles

- Clean, minimal UI like Anthropic/Claude
- Use Hotwire for real-time updates (live metrics via ActionCable)
- TimescaleDB hypertables for efficient time-series queries
- API-first design (dashboard sits on top of API)
- Pre-aggregate metrics for fast dashboard queries

## Kamal Production Access

**IMPORTANT**: When using `kamal app exec --reuse`, docker exec doesn't inherit container environment variables. You must pass `SECRET_KEY_BASE` explicitly.

```bash
# Navigate to this service directory
cd /Users/afmp/brainz/brainzlab/pulse

# Get the master key (used as SECRET_KEY_BASE)
cat config/master.key

# Run Rails console commands
kamal app exec -p --reuse -e SECRET_KEY_BASE:<master_key> 'bin/rails runner "<ruby_code>"'

# Example: Count records
kamal app exec -p --reuse -e SECRET_KEY_BASE:<master_key> 'bin/rails runner "puts Trace.count"'
```

### Running Complex Scripts

For multi-line Ruby scripts:

```bash
# 1. Create script locally
cat > /tmp/my_script.rb << 'RUBY'
Trace.order(duration_ms: :desc).limit(10).each { |t| puts "#{t.name}: #{t.duration_ms}ms" }
RUBY

# 2. Copy to server
scp /tmp/my_script.rb <user>@<primary-server>:/tmp/my_script.rb

# 3. Get container name and run
ssh <user>@<primary-server> 'CONTAINER=$(docker ps --filter "name=pulse-web" --format "{{.Names}}" | head -1) && \
  docker cp /tmp/my_script.rb $CONTAINER:/tmp/my_script.rb && \
  docker exec -e SECRET_KEY_BASE=<master_key> $CONTAINER bin/rails runner /tmp/my_script.rb'
```

### Other Kamal Commands

```bash
kamal deploy              # Deploy
kamal app logs -f         # View logs
kamal lock release        # Release stuck lock
kamal secrets print       # Print evaluated secrets
```
