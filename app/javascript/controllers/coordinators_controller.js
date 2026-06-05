import { Controller } from "@hotwired/stimulus"

// Múltiplos coordenadores/gestores de um centro de custo.
// Cada linha é um input separado name="cost_center[coordinator_list][]".
// As novas linhas são clonadas de um <template> para que o autocomplete
// (datalist) funcione em TODOS os campos (cloneNode de input não re-associa
// a datalist de forma confiável em alguns navegadores).
export default class extends Controller {
  static targets = ["list", "template", "row"]

  add(event) {
    event.preventDefault()
    const fragment = this.templateTarget.content.cloneNode(true)
    this.listTarget.appendChild(fragment)
    const inputs = this.listTarget.querySelectorAll("input")
    inputs[inputs.length - 1]?.focus()
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest("[data-coordinators-target='row']")
    if (!row) return
    if (this.rowTargets.length > 1) {
      row.remove()
    } else {
      row.querySelector("input").value = ""
    }
  }
}
