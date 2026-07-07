import { Controller } from "@hotwired/stimulus"

// Marca/desmarca todas as checkboxes de item dentro do escopo.
export default class extends Controller {
  static targets = ["item"]

  toggle(event) {
    this.itemTargets.forEach((c) => { c.checked = event.target.checked })
  }
}
