import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    type: { type: String, default: "line" },
    data: Array
  }

  connect() {
    this.initChart()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  async initChart() {
    const canvas = this.element.querySelector("canvas")
    if (!canvas) return

    const { Chart, registerables } = await import("https://cdn.jsdelivr.net/npm/chart.js@4.4.1/+esm")
    Chart.register(...registerables)

    const ctx = canvas.getContext("2d")
    const data = this.dataValue || []

    this.chart = new Chart(ctx, {
      type: this.typeValue,
      data: {
        labels: data.map(d => this.formatLabel(d.x)),
        datasets: [{
          data: data.map(d => d.y),
          borderColor: "#6366F1",
          backgroundColor: "rgba(99, 102, 241, 0.1)",
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
        interaction: {
          intersect: false,
          mode: "index"
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            backgroundColor: "#1A1A1A",
            titleColor: "#E8E5E0",
            bodyColor: "#E8E5E0",
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
              color: "#8B8780",
              font: { size: 11 },
              maxTicksLimit: 6
            }
          },
          y: {
            display: true,
            beginAtZero: true,
            grid: {
              color: "#F0EFED"
            },
            ticks: {
              color: "#8B8780",
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
