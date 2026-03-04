import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    nodes: Object,
    edges: Array
  }

  connect() {
    this.svg = this.element.querySelector("svg")
    if (!this.svg) return

    this.render()

    this.boundHandleDarkModeChange = this.handleDarkModeChange.bind(this)
    document.addEventListener("dark-mode:changed", this.boundHandleDarkModeChange)
  }

  disconnect() {
    if (this.boundHandleDarkModeChange) {
      document.removeEventListener("dark-mode:changed", this.boundHandleDarkModeChange)
    }
  }

  handleDarkModeChange() {
    this.render()
  }

  isDarkMode() {
    return document.documentElement.classList.contains("dark")
  }

  render() {
    const svg = this.svg
    const rect = svg.getBoundingClientRect()
    const width = rect.width || 800
    const height = rect.height || 500
    const isDark = this.isDarkMode()

    // Clear previous
    svg.innerHTML = ""
    svg.setAttribute("viewBox", `0 0 ${width} ${height}`)

    const nodes = this.nodesValue
    const edges = this.edgesValue
    const nodeKeys = Object.keys(nodes)

    if (nodeKeys.length === 0) return

    // Position nodes in a radial layout
    const positions = this.layoutNodes(nodeKeys, nodes, width, height)

    // Draw edges first (behind nodes)
    edges.forEach(edge => {
      const from = positions[edge.from]
      const to = positions[edge.to]
      if (!from || !to) return

      // Line
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line")
      line.setAttribute("x1", from.x)
      line.setAttribute("y1", from.y)
      line.setAttribute("x2", to.x)
      line.setAttribute("y2", to.y)
      line.setAttribute("stroke", edge.error_rate > 5 ? "#DC2626" : (isDark ? "#444" : "#D4D0CB"))
      line.setAttribute("stroke-width", Math.max(1, Math.min(4, Math.log2(edge.calls + 1))))
      line.setAttribute("stroke-dasharray", edge.error_rate > 5 ? "4,4" : "none")
      svg.appendChild(line)

      // Edge label
      const midX = (from.x + to.x) / 2
      const midY = (from.y + to.y) / 2

      const labelBg = document.createElementNS("http://www.w3.org/2000/svg", "rect")
      labelBg.setAttribute("x", midX - 35)
      labelBg.setAttribute("y", midY - 10)
      labelBg.setAttribute("width", 70)
      labelBg.setAttribute("height", 20)
      labelBg.setAttribute("rx", 4)
      labelBg.setAttribute("fill", isDark ? "#1a1a1a" : "#FFFFFE")
      labelBg.setAttribute("stroke", isDark ? "#333" : "#E8E5E0")
      labelBg.setAttribute("stroke-width", 1)
      svg.appendChild(labelBg)

      const label = document.createElementNS("http://www.w3.org/2000/svg", "text")
      label.setAttribute("x", midX)
      label.setAttribute("y", midY + 4)
      label.setAttribute("text-anchor", "middle")
      label.setAttribute("font-size", "10")
      label.setAttribute("fill", isDark ? "#a0a0a0" : "#8B8780")
      label.textContent = `${edge.calls} calls`
      if (edge.avg_ms) label.textContent += ` / ${edge.avg_ms}ms`
      svg.appendChild(label)
    })

    // Draw nodes
    nodeKeys.forEach(key => {
      const node = nodes[key]
      const pos = positions[key]
      if (!pos) return

      const color = this.nodeColor(node.type)
      const radius = key === "pulse" ? 35 : 28

      // Node circle
      const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle")
      circle.setAttribute("cx", pos.x)
      circle.setAttribute("cy", pos.y)
      circle.setAttribute("r", radius)
      circle.setAttribute("fill", color)
      circle.setAttribute("opacity", "0.15")
      circle.setAttribute("stroke", color)
      circle.setAttribute("stroke-width", 2)
      svg.appendChild(circle)

      // Inner circle
      const inner = document.createElementNS("http://www.w3.org/2000/svg", "circle")
      inner.setAttribute("cx", pos.x)
      inner.setAttribute("cy", pos.y)
      inner.setAttribute("r", radius * 0.6)
      inner.setAttribute("fill", color)
      inner.setAttribute("opacity", "0.3")
      svg.appendChild(inner)

      // Node label
      const text = document.createElementNS("http://www.w3.org/2000/svg", "text")
      text.setAttribute("x", pos.x)
      text.setAttribute("y", pos.y + radius + 16)
      text.setAttribute("text-anchor", "middle")
      text.setAttribute("font-size", "12")
      text.setAttribute("font-weight", "500")
      text.setAttribute("fill", isDark ? "#e0e0e0" : "#1A1A1A")
      text.textContent = node.name.length > 20 ? node.name.substring(0, 18) + "..." : node.name
      svg.appendChild(text)

      // Type icon letter inside circle
      const icon = document.createElementNS("http://www.w3.org/2000/svg", "text")
      icon.setAttribute("x", pos.x)
      icon.setAttribute("y", pos.y + 5)
      icon.setAttribute("text-anchor", "middle")
      icon.setAttribute("font-size", "14")
      icon.setAttribute("font-weight", "600")
      icon.setAttribute("fill", color)
      icon.textContent = this.nodeIcon(node.type)
      svg.appendChild(icon)
    })
  }

  layoutNodes(keys, nodes, width, height) {
    const positions = {}
    const centerX = width / 2
    const centerY = height / 2

    // Place the main app node in center
    const mainKey = keys.find(k => nodes[k].type === "app") || keys[0]
    positions[mainKey] = { x: centerX, y: centerY }

    // Place other nodes around it
    const others = keys.filter(k => k !== mainKey)
    const angleStep = (2 * Math.PI) / Math.max(others.length, 1)
    const radius = Math.min(width, height) * 0.32

    others.forEach((key, i) => {
      const angle = angleStep * i - Math.PI / 2
      positions[key] = {
        x: centerX + radius * Math.cos(angle),
        y: centerY + radius * Math.sin(angle)
      }
    })

    return positions
  }

  nodeColor(type) {
    switch (type) {
      case "app": return "#3B82F6"       // blue
      case "external": return "#22C55E"  // green
      case "database": return "#8B5CF6"  // purple
      case "cache": return "#F59E0B"     // amber
      default: return "#6B7280"          // gray
    }
  }

  nodeIcon(type) {
    switch (type) {
      case "app": return "APP"
      case "external": return "API"
      case "database": return "DB"
      case "cache": return "C"
      default: return "?"
    }
  }
}
