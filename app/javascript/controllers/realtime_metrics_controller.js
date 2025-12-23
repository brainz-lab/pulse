import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static values = {
    projectId: String
  }

  static targets = [
    "apdex", "apdexIndicator",
    "throughput",
    "responseTime", "responseTimeP95", "responseTimeP99",
    "errorRate", "errorCount", "errorIndicator",
    "recentTrace"
  ]

  connect() {
    this.traceCount = 0
    this.errorCount = 0
    this.durations = []
    this.lastMinute = new Date().getMinutes()

    this.subscribe()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  subscribe() {
    const projectId = this.projectIdValue

    this.subscription = consumer.subscriptions.create(
      { channel: "MetricsChannel", project_id: projectId },
      {
        connected: () => {
          console.log("[Pulse] Connected to real-time metrics")
        },
        disconnected: () => {
          console.log("[Pulse] Disconnected from real-time metrics")
        },
        received: (data) => {
          this.handleData(data)
        }
      }
    )
  }

  handleData(data) {
    if (data.type === "trace") {
      this.handleTrace(data.trace)
    } else if (data.type === "metrics") {
      this.handleMetrics(data.metrics)
    }
  }

  handleTrace(trace) {
    // Track for throughput calculation
    this.traceCount++

    // Track duration for response time
    if (trace.duration_ms) {
      this.durations.push(trace.duration_ms)
      // Keep last 100 for percentile calculations
      if (this.durations.length > 100) {
        this.durations.shift()
      }
    }

    // Track errors
    if (trace.error) {
      this.errorCount++
    }

    // Update recent traces list
    this.addRecentTrace(trace)

    // Check if minute changed for throughput update
    const currentMinute = new Date().getMinutes()
    if (currentMinute !== this.lastMinute) {
      this.updateThroughput()
      this.lastMinute = currentMinute
    }

    // Update response time stats
    this.updateResponseTimeStats()

    // Update error rate
    this.updateErrorRate()

    // Dispatch event for charts to update
    this.dispatch("trace", { detail: trace })
  }

  handleMetrics(metrics) {
    // Direct metrics update from aggregation
    if (metrics.apdex !== undefined && this.hasApdexTarget) {
      this.apdexTarget.textContent = metrics.apdex.toFixed(2)
      this.updateApdexIndicator(metrics.apdex)
    }

    if (metrics.rpm !== undefined && this.hasThroughputTarget) {
      this.throughputTarget.textContent = metrics.rpm.toLocaleString()
    }

    if (metrics.avg_duration !== undefined && this.hasResponseTimeTarget) {
      this.responseTimeTarget.innerHTML = `${Math.round(metrics.avg_duration)}<span class="text-[16px] font-normal">ms</span>`
    }

    if (metrics.error_rate !== undefined && this.hasErrorRateTarget) {
      this.errorRateTarget.textContent = `${metrics.error_rate.toFixed(1)}%`
    }
  }

  addRecentTrace(trace) {
    if (!this.hasRecentTraceTarget) return

    const template = this.recentTraceTarget.querySelector("template")
    if (!template) return

    const clone = template.content.cloneNode(true)
    const link = clone.querySelector("a")

    if (link) {
      link.href = link.href.replace("TRACE_ID", trace.id)
      link.querySelector("[data-duration]").textContent = `${Math.round(trace.duration_ms || 0)}ms`
      link.querySelector("[data-name]").textContent = trace.name
      link.querySelector("[data-time]").textContent = "just now"

      // Add to top of list
      const container = this.recentTraceTarget.querySelector("[data-traces]")
      if (container) {
        container.insertBefore(clone, container.firstChild)

        // Remove oldest if more than 5
        while (container.children.length > 5) {
          container.lastChild.remove()
        }
      }
    }
  }

  updateThroughput() {
    if (this.hasThroughputTarget) {
      this.throughputTarget.textContent = this.traceCount.toLocaleString()
    }
    this.traceCount = 0
  }

  updateResponseTimeStats() {
    if (this.durations.length === 0) return

    const sorted = [...this.durations].sort((a, b) => a - b)
    const avg = sorted.reduce((a, b) => a + b, 0) / sorted.length
    const p95 = sorted[Math.floor(sorted.length * 0.95)] || avg
    const p99 = sorted[Math.floor(sorted.length * 0.99)] || avg

    if (this.hasResponseTimeTarget) {
      this.responseTimeTarget.innerHTML = `${Math.round(avg)}<span class="text-[16px] font-normal">ms</span>`
    }

    if (this.hasResponseTimeP95Target) {
      this.responseTimeP95Target.textContent = `P95: ${Math.round(p95)}ms`
    }

    if (this.hasResponseTimeP99Target) {
      this.responseTimeP99Target.textContent = `P99: ${Math.round(p99)}ms`
    }
  }

  updateErrorRate() {
    const total = this.durations.length
    if (total === 0) return

    const rate = (this.errorCount / total) * 100

    if (this.hasErrorRateTarget) {
      this.errorRateTarget.textContent = `${rate.toFixed(1)}%`
      this.errorRateTarget.style.color = rate > 1 ? "#DC2626" : "#1A1A1A"
    }

    if (this.hasErrorCountTarget) {
      this.errorCountTarget.textContent = `${this.errorCount} errors`
    }

    if (this.hasErrorIndicatorTarget) {
      this.errorIndicatorTarget.style.display = rate > 1 ? "block" : "none"
    }
  }

  updateApdexIndicator(apdex) {
    if (!this.hasApdexIndicatorTarget) return

    let color = "#22C55E" // green
    if (apdex < 0.85) color = "#F59E0B" // amber
    if (apdex < 0.7) color = "#DC2626" // red

    this.apdexIndicatorTarget.style.backgroundColor = color
  }
}
