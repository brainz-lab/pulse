import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"

// Register all Chart.js components
Chart.register(...registerables)

export default class extends Controller {
  static values = {
    type: { type: String, default: "line" },
    data: Array,
    metric: String, // "throughput" or "response_time"
    maxPoints: { type: Number, default: 60 }
  }

  connect() {
    this.initChart()

    // Listen for real-time trace events
    if (this.metricValue) {
      this.boundHandleTrace = this.handleTrace.bind(this)
      document.addEventListener("realtime-metrics:trace", this.boundHandleTrace)
    }

    // Listen for dark mode changes
    this.boundHandleDarkModeChange = this.handleDarkModeChange.bind(this)
    document.addEventListener("dark-mode:changed", this.boundHandleDarkModeChange)
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
    if (this.boundHandleTrace) {
      document.removeEventListener("realtime-metrics:trace", this.boundHandleTrace)
    }
    if (this.boundHandleDarkModeChange) {
      document.removeEventListener("dark-mode:changed", this.boundHandleDarkModeChange)
    }
  }

  handleDarkModeChange() {
    // Reinitialize chart with new colors
    if (this.chart) {
      this.chart.destroy()
      this.initChart()
    }
  }

  isDarkMode() {
    return document.documentElement.classList.contains("dark")
  }

  getColors() {
    const isDark = this.isDarkMode()
    return {
      primary: "#6366F1",
      primaryBg: isDark ? "rgba(99, 102, 241, 0.2)" : "rgba(99, 102, 241, 0.1)",
      text: isDark ? "#a0a0a0" : "#8B8780",
      grid: isDark ? "#2a2a2a" : "#F0EFED",
      tooltip: {
        bg: isDark ? "#2a2a2a" : "#1A1A1A",
        text: isDark ? "#e8e1d7" : "#E8E5E0"
      }
    }
  }

  handleTrace(event) {
    const trace = event.detail

    if (this.metricValue === "throughput") {
      this.incrementCurrentPoint()
    } else if (this.metricValue === "response_time" && trace.duration_ms) {
      this.updateCurrentAverage(trace.duration_ms)
    }
  }

  incrementCurrentPoint() {
    if (!this.chart) return

    const data = this.chart.data.datasets[0].data
    const labels = this.chart.data.labels

    // Get current minute
    const now = new Date()
    const currentLabel = this.formatLabel(now.toISOString())

    // Check if we're still in the same minute
    if (labels[labels.length - 1] === currentLabel) {
      // Increment last point
      data[data.length - 1] = (data[data.length - 1] || 0) + 1
    } else {
      // Add new point
      this.addDataPoint(currentLabel, 1)
    }

    this.chart.update("none") // no animation for real-time
  }

  updateCurrentAverage(duration) {
    if (!this.chart) return

    const data = this.chart.data.datasets[0].data
    const labels = this.chart.data.labels

    const now = new Date()
    const currentLabel = this.formatLabel(now.toISOString())

    if (!this.avgState) {
      this.avgState = { sum: 0, count: 0 }
    }

    if (labels[labels.length - 1] === currentLabel) {
      // Update running average
      this.avgState.sum += duration
      this.avgState.count++
      data[data.length - 1] = Math.round(this.avgState.sum / this.avgState.count)
    } else {
      // Reset for new minute
      this.avgState = { sum: duration, count: 1 }
      this.addDataPoint(currentLabel, duration)
    }

    this.chart.update("none")
  }

  addDataPoint(label, value) {
    const data = this.chart.data.datasets[0].data
    const labels = this.chart.data.labels

    labels.push(label)
    data.push(value)

    // Remove oldest if over max
    while (labels.length > this.maxPointsValue) {
      labels.shift()
      data.shift()
    }
  }

  initChart() {
    const canvas = this.element.querySelector("canvas")
    if (!canvas) return

    const ctx = canvas.getContext("2d")
    const data = this.dataValue || []
    const colors = this.getColors()

    this.chart = new Chart(ctx, {
      type: this.typeValue,
      data: {
        labels: data.map(d => this.formatLabel(d.x)),
        datasets: [{
          data: data.map(d => d.y),
          borderColor: colors.primary,
          backgroundColor: colors.primaryBg,
          borderWidth: 2,
          fill: true,
          tension: 0.3,
          pointRadius: 0,
          pointHoverRadius: 4
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: {
          duration: 0 // disable for real-time performance
        },
        interaction: {
          intersect: false,
          mode: "index"
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            backgroundColor: colors.tooltip.bg,
            titleColor: colors.tooltip.text,
            bodyColor: colors.tooltip.text,
            padding: 12,
            cornerRadius: 8,
            displayColors: false
          }
        },
        scales: {
          x: {
            display: true,
            grid: {
              display: false
            },
            ticks: {
              color: colors.text,
              font: { size: 11 },
              maxTicksLimit: 6
            }
          },
          y: {
            display: true,
            beginAtZero: true,
            grid: {
              color: colors.grid
            },
            ticks: {
              color: colors.text,
              font: { size: 11 },
              maxTicksLimit: 5
            }
          }
        }
      }
    })
  }

  formatLabel(isoString) {
    if (!isoString) return ""
    const date = new Date(isoString)
    return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
  }
}
