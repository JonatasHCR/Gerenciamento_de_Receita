import { Controller } from "@hotwired/stimulus"

// Alterna a visibilidade de um campo de senha (botão de olho).
export default class extends Controller {
  static targets = ["field", "eye", "eyeSlash"]

  toggle() {
    const reveal = this.fieldTarget.type === "password"
    this.fieldTarget.type = reveal ? "text" : "password"
    this.eyeTarget.classList.toggle("hidden", reveal)
    this.eyeSlashTarget.classList.toggle("hidden", !reveal)
  }
}
