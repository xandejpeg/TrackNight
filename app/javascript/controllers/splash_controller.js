import { Controller } from "@hotwired/stimulus"

// Tela zero (splash): bandeirada animada antes da landing.
// Aparece 1x por sessão; respeita prefers-reduced-motion; pular com clique/tecla.
export default class extends Controller {
  static targets = ["splash"]

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches ||
        sessionStorage.getItem("tn_splash_seen") === "1") {
      this.skip(true)
      return
    }
    document.body.style.overflow = "hidden"
    this.element.classList.remove("hidden")
    // Força reflow para a animação CSS iniciar
    void this.element.offsetWidth
    this.element.classList.add("splash-running")

    this.timeout = setTimeout(() => this.finish(), 2600)
    this.boundSkip = this.skip.bind(this)
    this.element.addEventListener("click", this.boundSkip)
    this.boundKey = (e) => { if (e.key === "Escape" || e.key === "Enter" || e.key === " ") this.skip() }
    window.addEventListener("keydown", this.boundKey)
  }

  disconnect() {
    clearTimeout(this.timeout)
    window.removeEventListener("keydown", this.boundKey)
    document.body.style.overflow = ""
  }

  skip(instant = false) {
    sessionStorage.setItem("tn_splash_seen", "1")
    if (instant) { this.finish(); return }
    this.finish()
  }

  finish() {
    clearTimeout(this.timeout)
    sessionStorage.setItem("tn_splash_seen", "1")
    this.element.classList.add("splash-done")
    document.body.style.overflow = ""
    setTimeout(() => this.element.remove(), 700)
  }
}
