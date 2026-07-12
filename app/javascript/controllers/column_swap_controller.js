import { Controller } from "@hotwired/stimulus"

// Permite trocar colunas inteiras da tabela de revisão do OCR.
// Clique em um cabeçalho para selecioná-lo e em outro para trocar os valores,
// ou arraste um cabeçalho e solte sobre outro. Os tempos não mudam — só o
// lugar (o significado da coluna) é trocado.
export default class extends Controller {
  static targets = ["header"]

  connect() {
    this.selected = null
    this.headerTargets.forEach((th) => {
      th.setAttribute("draggable", "true")
      th.classList.add("col-swap-header")
    })
  }

  select(event) {
    const th = event.currentTarget
    if (this.selected === th) {
      this.deselect()
      return
    }
    if (this.selected) {
      this.swap(this.selected.dataset.field, th.dataset.field)
      this.flash(this.selected, th)
      this.deselect()
      return
    }
    this.selected = th
    th.classList.add("col-swap-selected")
  }

  deselect() {
    if (this.selected) this.selected.classList.remove("col-swap-selected")
    this.selected = null
  }

  dragStart(event) {
    this.deselect()
    event.dataTransfer.setData("text/plain", event.currentTarget.dataset.field)
    event.dataTransfer.effectAllowed = "move"
    event.currentTarget.classList.add("col-swap-dragging")
  }

  dragEnd(event) {
    event.currentTarget.classList.remove("col-swap-dragging")
    this.headerTargets.forEach((th) => th.classList.remove("col-swap-over"))
  }

  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    event.currentTarget.classList.add("col-swap-over")
  }

  dragLeave(event) {
    event.currentTarget.classList.remove("col-swap-over")
  }

  drop(event) {
    event.preventDefault()
    const from = event.dataTransfer.getData("text/plain")
    const to = event.currentTarget.dataset.field
    event.currentTarget.classList.remove("col-swap-over")
    if (!from || !to || from === to) return
    this.swap(from, to)
    const fromTh = this.headerTargets.find((th) => th.dataset.field === from)
    this.flash(fromTh, event.currentTarget)
  }

  swap(fieldA, fieldB) {
    const inputsA = this.columnInputs(fieldA)
    const inputsB = this.columnInputs(fieldB)
    const size = Math.min(inputsA.length, inputsB.length)
    for (let i = 0; i < size; i++) {
      const tmp = inputsA[i].value
      inputsA[i].value = inputsB[i].value
      inputsB[i].value = tmp
    }
  }

  columnInputs(field) {
    return Array.from(
      this.element.querySelectorAll(`input[name$="[${field}]"]`)
    )
  }

  flash(...headers) {
    headers.forEach((th) => {
      if (!th) return
      th.classList.add("col-swap-flash")
      setTimeout(() => th.classList.remove("col-swap-flash"), 700)
    })
  }
}
