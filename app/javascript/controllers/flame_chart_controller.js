import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    spans: Array,
    traceStart: Number  // epoch ms of trace start
  }

  connect() {
    this.canvas = this.element.querySelector("canvas")
    if (!this.canvas || !this.spansValue.length) return

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

    const spans = this.spansValue
    if (!spans.length) return

    const traceStart = this.traceStartValue
    const traceEnd = Math.max(...spans.map(s => (s.started_at_ms || 0) + (s.duration_ms || 0)))
    const totalDuration = traceEnd - traceStart
    if (totalDuration <= 0) return

    // Build depth map using parent_span_id
    const depthMap = this.computeDepths(spans)
    const maxDepth = Math.max(...Object.values(depthMap), 0) + 1

    const barHeight = Math.min(28, Math.max(16, (height - 40) / maxDepth))
    const paddingLeft = 10
    const paddingTop = 10
    const chartWidth = width - paddingLeft * 2

    // Draw each span as a bar
    spans.forEach(span => {
      const startOffset = (span.started_at_ms || 0) - traceStart
      const duration = span.duration_ms || 0
      const depth = depthMap[span.span_id] || 0

      const x = paddingLeft + (startOffset / totalDuration) * chartWidth
      const y = paddingTop + depth * (barHeight + 2)
      const w = Math.max(2, (duration / totalDuration) * chartWidth)

      const color = this.spanColor(span.kind)

      // Bar background
      ctx.fillStyle = color
      ctx.globalAlpha = 0.85
      ctx.beginPath()
      if (ctx.roundRect) {
        ctx.roundRect(x, y, w, barHeight, 3)
      } else {
        ctx.rect(x, y, w, barHeight)
      }
      ctx.fill()
      ctx.globalAlpha = 1

      // Bar border
      ctx.strokeStyle = isDark ? "rgba(255,255,255,0.15)" : "rgba(0,0,0,0.1)"
      ctx.lineWidth = 0.5
      ctx.stroke()

      // Label (only if bar is wide enough)
      if (w > 40) {
        ctx.fillStyle = "#fff"
        ctx.font = `500 ${Math.min(11, barHeight - 6)}px Inter, system-ui, sans-serif`
        ctx.textBaseline = "middle"
        const label = `${span.name || span.kind} (${duration.toFixed(1)}ms)`
        const maxChars = Math.floor(w / 6)
        ctx.fillText(label.substring(0, maxChars), x + 4, y + barHeight / 2)
      }
    })

    // Time axis
    ctx.fillStyle = isDark ? "#888" : "#8B8780"
    ctx.font = "11px Inter, system-ui, sans-serif"
    ctx.textBaseline = "top"
    const axisY = paddingTop + maxDepth * (barHeight + 2) + 4

    ctx.fillText("0ms", paddingLeft, axisY)
    ctx.textAlign = "center"
    ctx.fillText(`${(totalDuration / 2).toFixed(0)}ms`, width / 2, axisY)
    ctx.textAlign = "end"
    ctx.fillText(`${totalDuration.toFixed(0)}ms`, width - paddingLeft, axisY)
    ctx.textAlign = "start"
  }

  computeDepths(spans) {
    const depthMap = {}
    const childrenOf = {}

    // Build parent->children map
    spans.forEach(span => {
      const parent = span.parent_span_id
      if (parent) {
        if (!childrenOf[parent]) childrenOf[parent] = []
        childrenOf[parent].push(span.span_id)
      }
    })

    // Find roots (no parent or parent not in this trace)
    const spanIds = new Set(spans.map(s => s.span_id))
    const roots = spans.filter(s => !s.parent_span_id || !spanIds.has(s.parent_span_id))

    // BFS to assign depths
    const queue = roots.map(r => ({ id: r.span_id, depth: 0 }))
    while (queue.length > 0) {
      const { id, depth } = queue.shift()
      depthMap[id] = depth
      const children = childrenOf[id] || []
      children.forEach(childId => {
        queue.push({ id: childId, depth: depth + 1 })
      })
    }

    // Any orphans get depth 0
    spans.forEach(s => {
      if (depthMap[s.span_id] === undefined) {
        depthMap[s.span_id] = 0
      }
    })

    return depthMap
  }

  spanColor(kind) {
    switch (kind) {
      case "db": return "#3B82F6"         // blue
      case "http": return "#22C55E"       // green
      case "cache": return "#F59E0B"      // amber
      case "render": return "#8B5CF6"     // purple
      default: return "#6B7280"           // gray
    }
  }
}
