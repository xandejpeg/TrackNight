import { Controller } from "@hotwired/stimulus"

// Gráfico de evolução das voltas (Chart.js UMD carregado sob demanda).
export default class extends Controller {
  static targets = ["canvas"]
  static values = { points: Array, split: Boolean }

  async connect() {
    if (!this.pointsValue.length) return
    await import("chart.js") // UMD: registra window.Chart
    this.render()
  }

  disconnect() {
    this.chart?.destroy()
  }

  render() {
    const Chart = window.Chart
    if (!Chart) return

    const fmt = (ms) => {
      if (ms == null) return "—"
      const m = Math.floor(ms / 60000)
      const s = ((ms % 60000) / 1000).toFixed(3)
      return m > 0 ? `${m}:${s.padStart(6, "0")}` : s
    }

    const datasets = this.splitValue ? this.splitDatasets() : this.singleDatasets()
    const labels = this.pointsValue.map((p) => p.label)

    this.chart = new Chart(this.canvasTarget, {
      type: "line",
      data: { labels, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: {
            labels: { color: "#8b8b96", boxWidth: 12, boxHeight: 12, usePointStyle: true, font: { size: 11 } }
          },
          tooltip: {
            backgroundColor: "rgba(14,14,18,0.95)",
            borderColor: "rgba(255,255,255,0.1)",
            borderWidth: 1,
            titleColor: "#fff",
            bodyColor: "#d5d5dd",
            padding: 12,
            callbacks: {
              label: (ctx) => ` ${ctx.dataset.label}: ${fmt(ctx.parsed.y)}`
            }
          }
        },
        scales: {
          x: {
            ticks: { color: "#8b8b96", font: { size: 10, family: "monospace" }, maxRotation: 45 },
            grid: { color: "rgba(255,255,255,0.04)" }
          },
          y: {
            reverse: false,
            ticks: { color: "#8b8b96", font: { size: 10, family: "monospace" }, callback: (v) => fmt(v) },
            grid: { color: "rgba(255,255,255,0.05)" }
          }
        }
      }
    })
  }

  singleDatasets() {
    return [
      {
        label: "Melhor volta",
        data: this.pointsValue.map((p) => p.best_ms),
        borderColor: "#e10600",
        backgroundColor: "rgba(225,6,0,0.12)",
        pointBackgroundColor: this.pointsValue.map((p) => p.profile_color || "#e10600"),
        pointRadius: 5,
        pointHoverRadius: 7,
        borderWidth: 2.5,
        tension: 0.35,
        fill: true
      },
      {
        label: "Volta ideal",
        data: this.pointsValue.map((p) => p.ideal_ms),
        borderColor: "rgba(0,168,232,0.85)",
        borderDash: [6, 5],
        pointRadius: 3,
        borderWidth: 1.5,
        tension: 0.35,
        fill: false
      }
    ]
  }

  splitDatasets() {
    const byProfile = { ACF: [], AC: [] }
    this.pointsValue.forEach((p, i) => {
      if (byProfile[p.profile]) {
        byProfile[p.profile].push({ x: i, y: p.best_ms })
      }
    })
    return [
      { label: "ACF", data: this.pointsValue.map((p) => (p.profile === "ACF" ? p.best_ms : null)), borderColor: "#e10600", backgroundColor: "#e10600", pointRadius: 5, borderWidth: 2.5, tension: 0.3, spanGaps: true },
      { label: "AC (smurf)", data: this.pointsValue.map((p) => (p.profile === "AC" ? p.best_ms : null)), borderColor: "#00a8e8", backgroundColor: "#00a8e8", pointRadius: 5, borderWidth: 2.5, tension: 0.3, spanGaps: true }
    ]
  }
}
