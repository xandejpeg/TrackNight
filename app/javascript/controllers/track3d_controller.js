import { Controller } from "@hotwired/stimulus"

// Mapa 3D do traçado: extrusão do path SVG com Three.js (carregado sob demanda).
export default class extends Controller {
  static targets = ["stage"]
  static values = { path: String }

  async connect() {
    if (!this.pathValue) return
    const THREE = await import("three")
    this.THREE = THREE
    this.setup()
  }

  disconnect() {
    cancelAnimationFrame(this.frame)
    this.renderer?.dispose()
    this.stageTarget.replaceChildren()
  }

  setup() {
    const THREE = this.THREE
    const stage = this.stageTarget
    const width = stage.clientWidth
    const height = stage.clientHeight

    this.scene = new THREE.Scene()
    this.scene.fog = new THREE.Fog(0x060608, 500, 1400)

    this.camera = new THREE.PerspectiveCamera(45, width / height, 1, 3000)
    this.camera.position.set(0, 420, 480)
    this.camera.lookAt(0, 0, 0)

    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
    this.renderer.setSize(width, height)
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    stage.appendChild(this.renderer.domElement)

    // Luzes noturnas
    this.scene.add(new THREE.AmbientLight(0x404050, 1.2))
    const key = new THREE.DirectionalLight(0xffffff, 1.6)
    key.position.set(200, 400, 200)
    this.scene.add(key)
    const redGlow = new THREE.PointLight(0xe10600, 2.2, 900)
    redGlow.position.set(-150, 120, -100)
    this.scene.add(redGlow)
    const blueGlow = new THREE.PointLight(0x00a8e8, 1.4, 900)
    blueGlow.position.set(200, 100, 150)
    this.scene.add(blueGlow)

    this.track = this.buildTrack()
    this.scene.add(this.track)

    // Chão
    const ground = new THREE.Mesh(
      new THREE.CircleGeometry(560, 64),
      new THREE.MeshStandardMaterial({ color: 0x0a0a0e, roughness: 0.95 })
    )
    ground.rotation.x = -Math.PI / 2
    ground.position.y = -6
    this.scene.add(ground)

    this.setupOrbit()
    this.animate()
  }

  // Amostra o path SVG em pontos e extruda o "asfalto".
  buildTrack() {
    const THREE = this.THREE
    const svgNS = "http://www.w3.org/2000/svg"
    const svg = document.createElementNS(svgNS, "svg")
    const pathEl = document.createElementNS(svgNS, "path")
    pathEl.setAttribute("d", this.pathValue)
    svg.appendChild(pathEl)

    const total = pathEl.getTotalLength()
    const samples = 260
    const pts = []
    let cx = 0, cz = 0
    for (let i = 0; i <= samples; i++) {
      const p = pathEl.getPointAtLength((i / samples) * total)
      pts.push(p)
      cx += p.x; cz += p.y
    }
    cx /= pts.length; cz /= pts.length

    const points3d = pts.map((p) => new this.THREE.Vector3(p.x - cx, 0, p.y - cz))
    const curve = new THREE.CatmullRomCurve3(points3d, true)

    const group = new THREE.Group()

    // Asfalto: tubo achatado
    const tube = new THREE.Mesh(
      new THREE.TubeGeometry(curve, 400, 14, 8, true),
      new THREE.MeshStandardMaterial({ color: 0x2b2b33, roughness: 0.7, metalness: 0.15 })
    )
    tube.scale.y = 0.18
    group.add(tube)

    // Linha central luminosa
    const line = new THREE.Mesh(
      new THREE.TubeGeometry(curve, 400, 1.6, 6, true),
      new THREE.MeshBasicMaterial({ color: 0xe10600 })
    )
    line.position.y = 3.2
    group.add(line)

    // "Kart" percorrendo o traçado
    this.carCurve = curve
    this.car = new THREE.Mesh(
      new THREE.SphereGeometry(5, 16, 16),
      new THREE.MeshBasicMaterial({ color: 0xffffff })
    )
    const halo = new THREE.PointLight(0xffffff, 1.6, 120)
    this.car.add(halo)
    group.add(this.car)

    return group
  }

  setupOrbit() {
    let dragging = false
    let lastX = 0, lastY = 0
    this.theta = 0
    this.phi = 0.75
    this.radius = 640

    const el = this.renderer.domElement
    el.style.cursor = "grab"
    el.addEventListener("pointerdown", (e) => { dragging = true; lastX = e.clientX; lastY = e.clientY; el.style.cursor = "grabbing" })
    window.addEventListener("pointerup", () => { dragging = false; el.style.cursor = "grab" })
    window.addEventListener("pointermove", (e) => {
      if (!dragging) return
      this.theta -= (e.clientX - lastX) * 0.005
      this.phi = Math.min(1.35, Math.max(0.25, this.phi - (e.clientY - lastY) * 0.004))
      lastX = e.clientX; lastY = e.clientY
    })
    el.addEventListener("wheel", (e) => {
      e.preventDefault()
      this.radius = Math.min(1000, Math.max(280, this.radius + e.deltaY * 0.6))
    }, { passive: false })
  }

  animate() {
    this.frame = requestAnimationFrame(() => this.animate())
    const t = performance.now() / 1000

    if (!this.userInteracted) this.theta += 0.0016

    this.camera.position.set(
      this.radius * Math.sin(this.phi) * Math.sin(this.theta),
      this.radius * Math.cos(this.phi),
      this.radius * Math.sin(this.phi) * Math.cos(this.theta)
    )
    this.camera.lookAt(0, 0, 0)

    if (this.car && this.carCurve) {
      const pos = this.carCurve.getPointAt((t * 0.045) % 1)
      this.car.position.set(pos.x, 6, pos.z)
    }

    this.renderer.render(this.scene, this.camera)
  }
}
