import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    data: Array,
    buckets: Array  // labels for y-axis buckets
  }

  connect() {
    this.canvas = this.element.querySelector("canvas")
    if (!this.canvas) return

    this.render()

    this.boundResize = this.render.bind(this)
    window.addEventListener("resize", this.boundResize)

    this.boundHandleDarkModeChange = this.render.bind(this)
    document.addEventListener("dark-mode:changed", this.boundHandleDarkModeChange)
  }

  disconnect() {
    if (this.boundResize) {
      window.removeEventListener("resize", this.boundResize)
    }
    if (this.boundHandleDarkModeChange) {
      document.removeEventListener("dark-mode:changed", this.boundHandleDarkModeChange)
    }
  }

  isDarkMode() {
    return document.documentElement.classList.contains("dark")
  }

  render() {
    const canvas = this.canvas
    const container = canvas.parentElement
    const dpr = window.devicePixelRatio || 1

    canvas.width = container.clientWidth * dpr
    canvas.height = container.clientHeight * dpr
    canvas.style.width = container.clientWidth + "px"
    canvas.style.height = container.clientHeight + "px"

    const ctx = canvas.getContext("2d")
    ctx.scale(dpr, dpr)

    const width = container.clientWidth
    const height = container.clientHeight
    const isDark = this.isDarkMode()

    // Clear
    ctx.clearRect(0, 0, width, height)

    const data = this.dataValue
    const bucketLabels = this.bucketsValue || ["0-50ms", "50-100ms", "100-200ms", "200-500ms", "500ms-1s", "1-2s", "2-5s", "5s+"]

    if (!data || data.length === 0) {
      ctx.fillStyle = isDark ? "#888" : "#8B8780"
      ctx.font = "14px Inter, system-ui, sans-serif"
      ctx.textAlign = "center"
      ctx.fillText("No data available", width / 2, height / 2)
      return
    }

    const numBuckets = bucketLabels.length
    const paddingLeft = 70
    const paddingBottom = 30
    const paddingTop = 10
    const paddingRight = 10

    const chartWidth = width - paddingLeft - paddingRight
    const chartHeight = height - paddingBottom - paddingTop

    const cellWidth = chartWidth / data.length
    const cellHeight = chartHeight / numBuckets

    // Extract bucket keys from first data row (excluding bucket_time)
    const firstRow = data[0]
    const bucketKeys = Object.keys(firstRow).filter(k => k !== "bucket_time" && k.startsWith("bucket_"))

    // Find max value for color scaling
    let maxVal = 0
    data.forEach(row => {
      bucketKeys.forEach(key => {
        const val = parseInt(row[key]) || 0
        if (val > maxVal) maxVal = val
      })
    })

    // Draw cells
    data.forEach((row, col) => {
      bucketKeys.forEach((key, rowIdx) => {
        const val = parseInt(row[key]) || 0
        const x = paddingLeft + col * cellWidth
        // Invert y so higher latencies are at top
        const y = paddingTop + (numBuckets - 1 - rowIdx) * cellHeight

        if (val > 0) {
          const intensity = Math.min(1, val / Math.max(maxVal, 1))
          ctx.fillStyle = this.heatColor(intensity, isDark)
        } else {
          ctx.fillStyle = isDark ? "#1a1a1a" : "#FAFAF8"
        }

        ctx.fillRect(x, y, cellWidth - 1, cellHeight - 1)
      })
    })

    // Y-axis labels (bucket labels)
    ctx.fillStyle = isDark ? "#888" : "#8B8780"
    ctx.font = "10px Inter, system-ui, sans-serif"
    ctx.textAlign = "right"
    ctx.textBaseline = "middle"
    bucketLabels.forEach((label, i) => {
      const y = paddingTop + (numBuckets - 1 - i) * cellHeight + cellHeight / 2
      ctx.fillText(label, paddingLeft - 6, y)
    })

    // X-axis labels (time)
    ctx.textAlign = "center"
    ctx.textBaseline = "top"
    const labelInterval = Math.max(1, Math.floor(data.length / 6))
    data.forEach((row, i) => {
      if (i % labelInterval === 0) {
        const x = paddingLeft + i * cellWidth + cellWidth / 2
        const time = new Date(row.bucket_time)
        ctx.fillText(time.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }), x, height - paddingBottom + 6)
      }
    })

    // Color scale legend
    const legendX = width - 120
    const legendY = paddingTop
    const legendWidth = 100
    const legendHeight = 10

    const gradient = ctx.createLinearGradient(legendX, legendY, legendX + legendWidth, legendY)
    if (isDark) {
      gradient.addColorStop(0, "#1a1a1a")
      gradient.addColorStop(0.25, "#1e3a5f")
      gradient.addColorStop(0.5, "#2563EB")
      gradient.addColorStop(0.75, "#7C3AED")
      gradient.addColorStop(1, "#DC2626")
    } else {
      gradient.addColorStop(0, "#FAFAF8")
      gradient.addColorStop(0.25, "#BFDBFE")
      gradient.addColorStop(0.5, "#3B82F6")
      gradient.addColorStop(0.75, "#8B5CF6")
      gradient.addColorStop(1, "#DC2626")
    }
    ctx.fillStyle = gradient
    ctx.fillRect(legendX, legendY, legendWidth, legendHeight)

    ctx.fillStyle = isDark ? "#888" : "#8B8780"
    ctx.font = "9px Inter, system-ui, sans-serif"
    ctx.textAlign = "left"
    ctx.fillText("0", legendX, legendY + legendHeight + 10)
    ctx.textAlign = "right"
    ctx.fillText(maxVal.toString(), legendX + legendWidth, legendY + legendHeight + 10)
  }

  heatColor(intensity, isDark) {
    // Blue -> Purple -> Red gradient
    if (intensity < 0.33) {
      const t = intensity / 0.33
      if (isDark) {
        return `rgba(37, 99, 235, ${0.2 + t * 0.6})`  // blue
      }
      return `rgba(59, 130, 246, ${0.15 + t * 0.5})`
    } else if (intensity < 0.66) {
      const t = (intensity - 0.33) / 0.33
      if (isDark) {
        const r = Math.round(37 + t * (139 - 37))
        const g = Math.round(99 + t * (92 - 99))
        const b = Math.round(235 + t * (246 - 235))
        return `rgba(${r}, ${g}, ${b}, 0.8)`
      }
      const r = Math.round(59 + t * (139 - 59))
      const g = Math.round(130 + t * (92 - 130))
      const b = Math.round(246 + t * (246 - 246))
      return `rgba(${r}, ${g}, ${b}, 0.7)`
    } else {
      const t = (intensity - 0.66) / 0.34
      if (isDark) {
        return `rgba(${Math.round(139 + t * 81)}, ${Math.round(92 - t * 54)}, ${Math.round(246 - t * 208)}, 0.9)`
      }
      return `rgba(${Math.round(139 + t * 81)}, ${Math.round(92 - t * 54)}, ${Math.round(246 - t * 208)}, 0.85)`
    }
  }
}
