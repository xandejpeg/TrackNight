import { Controller } from "@hotwired/stimulus"

// Gráfico de evolução das voltas (Chart.js UMD carregado sob demanda).
// Marca mudanças de condição de pista (seco → chuva/tempestade) com faixas
// coloridas e rótulos, já que o tempo sobe de repente nessas provas.
const WET_STYLES = {
  chuva_fraca: { color: "#38bdf8", label: "🌦 Chuva fraca" },
  chuva_moderada: { color: "#ffd166", label: "🌧 Chuva moderada" },
  tempestade: { color: "#a855f7", label: "🌩 Tempestade (pista inundada)" }
}

export default class extends Controller {
  static targets = ["canvas", "mergeBtn", "splitBtn", "sectorsBtn", "idealBtn"]
  static values = { points: Array, split: Boolean }

  async connect() {
    if (!this.pointsValue.length) return
    this.showSectors = false
    this.showIdeal = true
    await import("chart.js") // UMD: registra window.Chart
    this.render()
  }

  disconnect() {
    this.chart?.destroy()
  }

  merge() { this.splitValue = false; this.rerender() }
  split() { this.splitValue = true; this.rerender() }
  toggleSectors() { this.showSectors = !this.showSectors; this.rerender() }
  toggleIdeal() { this.showIdeal = !this.showIdeal; this.rerender() }

  rerender() {
    this.chart?.destroy()
    this.render()
    if (this.hasMergeBtnTarget && this.hasSplitBtnTarget) {
      this.mergeBtnTarget.classList.toggle("filter-pill-active", !this.splitValue)
      this.splitBtnTarget.classList.toggle("filter-pill-active", this.splitValue)
    }
    if (this.hasSectorsBtnTarget) this.sectorsBtnTarget.classList.toggle("filter-pill-active", this.showSectors)
    if (this.hasIdealBtnTarget) this.idealBtnTarget.classList.toggle("filter-pill-active", this.showIdeal)
  }

  wetStyle(p) {
    return WET_STYLES[p.weather_key] || null
  }

  // Plugin: faixas verticais nas provas de pista molhada + linha tracejada
  // com rótulo onde a condição muda em relação à corrida anterior.
  conditionPlugin() {
    const points = this.pointsValue
    return {
      id: "trackConditions",
      beforeDatasetsDraw(chart) {
        const { ctx, chartArea, scales } = chart
        if (!chartArea) return
        const x = scales.x
        const half = points.length > 1 ? (x.getPixelForValue(1) - x.getPixelForValue(0)) / 2 : 40

        points.forEach((p, i) => {
          const style = WET_STYLES[p.weather_key]
          if (!style) return
          const cx = x.getPixelForValue(i)
          const left = Math.max(chartArea.left, cx - half)
          const right = Math.min(chartArea.right, cx + half)
          ctx.save()
          ctx.fillStyle = style.color + "1f"
          ctx.fillRect(left, chartArea.top, right - left, chartArea.bottom - chartArea.top)
          ctx.restore()
        })
      },
      afterDatasetsDraw(chart) {
        const { ctx, chartArea, scales } = chart
        if (!chartArea) return
        const x = scales.x
        const wetKind = (p) => (WET_STYLES[p.weather_key] ? p.weather_key : "seco")

        points.forEach((p, i) => {
          if (i === 0) return
          const kind = wetKind(p)
          const prev = wetKind(points[i - 1])
          if (kind === prev) return

          const style = WET_STYLES[p.weather_key] || { color: "#2dd4a7", label: "🏁 Pista seca" }
          const cx = x.getPixelForValue(i)
          const prevCx = x.getPixelForValue(i - 1)
          const lineX = (cx + prevCx) / 2

          ctx.save()
          ctx.strokeStyle = style.color
          ctx.setLineDash([5, 4])
          ctx.lineWidth = 1.5
          ctx.beginPath()
          ctx.moveTo(lineX, chartArea.top)
          ctx.lineTo(lineX, chartArea.bottom)
          ctx.stroke()
          ctx.setLineDash([])

          const text = style.label
          ctx.font = "bold 10px sans-serif"
          const w = ctx.measureText(text).width + 12
          const bx = Math.min(Math.max(lineX - w / 2, chartArea.left), chartArea.right - w)
          const by = chartArea.top + 4 + (i % 2) * 18
          ctx.fillStyle = "rgba(10,10,14,0.92)"
          ctx.strokeStyle = style.color + "88"
          ctx.lineWidth = 1
          ctx.beginPath()
          ctx.roundRect(bx, by, w, 16, 8)
          ctx.fill()
          ctx.stroke()
          ctx.fillStyle = style.color
          ctx.textAlign = "center"
          ctx.textBaseline = "middle"
          ctx.fillText(text, bx + w / 2, by + 8.5)
          ctx.restore()
        })
      }
    }
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
    if (this.showSectors) datasets.push(...this.sectorDatasets())
    const labels = this.pointsValue.map((p) => p.label)

    const scales = {
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
    if (this.showSectors) {
      scales.y1 = {
        position: "right",
        ticks: { color: "#6b6b76", font: { size: 9, family: "monospace" }, callback: (v) => fmt(v) },
        grid: { drawOnChartArea: false }
      }
    }

    this.chart = new Chart(this.canvasTarget, {
      type: "line",
      data: { labels, datasets },
      plugins: [this.conditionPlugin()],
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
              label: (ctx) => ` ${ctx.dataset.label}: ${fmt(ctx.parsed.y)}`,
              afterTitle: (items) => {
                const p = this.pointsValue[items[0]?.dataIndex]
                if (!p) return ""
                const parts = [p.session_title, p.profile, p.weather_icon].filter(Boolean)
                return parts.join(" · ")
              },
              afterBody: (items) => {
                const p = this.pointsValue[items[0]?.dataIndex]
                if (!p) return ""
                const lines = []
                if (p.position) lines.push(`Posição: P${p.position}`)
                if (p.kart) lines.push(`Kart: #${p.kart}`)
                if (p.speed) lines.push(`Vel. máx: ${p.speed} km/h`)
                if (p.weather) lines.push(`Pista: ${p.weather}`)
                return lines
              }
            }
          }
        },
        scales
      }
    })
  }

  pointColors() {
    return this.pointsValue.map((p) => this.wetStyle(p)?.color || p.profile_color || "#e10600")
  }

  singleDatasets() {
    const sets = [
      {
        label: "Melhor volta",
        data: this.pointsValue.map((p) => p.best_ms),
        borderColor: "#e10600",
        backgroundColor: "rgba(225,6,0,0.12)",
        pointBackgroundColor: this.pointColors(),
        pointBorderColor: this.pointColors(),
        pointRadius: 5,
        pointHoverRadius: 7,
        borderWidth: 2.5,
        tension: 0.35,
        fill: true
      }
    ]
    if (this.showIdeal) {
      sets.push({
        label: "Volta ideal",
        data: this.pointsValue.map((p) => p.ideal_ms),
        borderColor: "rgba(0,168,232,0.85)",
        borderDash: [6, 5],
        pointRadius: 3,
        borderWidth: 1.5,
        tension: 0.35,
        fill: false
      })
    }
    return sets
  }

  splitDatasets() {
    const wet = this.pointColors()
    // Uma linha por conta presente nos pontos (funciona com qualquer nº de contas).
    const profiles = []
    this.pointsValue.forEach((p) => {
      if (p.profile && !profiles.some((x) => x.code === p.profile)) {
        profiles.push({ code: p.profile, color: p.profile_color || "#8b8b96" })
      }
    })
    return profiles.map((prof) => ({
      label: prof.code,
      data: this.pointsValue.map((p) => (p.profile === prof.code ? p.best_ms : null)),
      borderColor: prof.color, backgroundColor: prof.color,
      pointBackgroundColor: wet, pointBorderColor: wet,
      pointRadius: 5, borderWidth: 2.5, tension: 0.3, spanGaps: true
    }))
  }

  sectorDatasets() {
    const mk = (label, key, color) => ({
      label,
      data: this.pointsValue.map((p) => p[key]),
      borderColor: color,
      pointRadius: 2.5,
      borderWidth: 1.5,
      tension: 0.35,
      fill: false,
      yAxisID: "y1"
    })
    return [
      mk("S1", "s1_ms", "#c084fc"),
      mk("S2", "s2_ms", "#2dd4a7"),
      mk("S3", "s3_ms", "#ffd166")
    ]
  }
}
