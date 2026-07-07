import { Controller } from "@hotwired/stimulus"

// Mantém o link "Baixar Modelo" refletindo os checkboxes marcados: o modelo baixado
// traz só as abas escolhidas (nenhuma marcada = modelo completo).
export default class extends Controller {
  static targets = ["link"]
  static values = { url: String }

  connect() { this.update() }

  update() {
    const checked = Array.from(
      this.element.querySelectorAll('input[name="targets[]"]:checked')
    ).map((c) => c.value)

    const url = new URL(this.urlValue, window.location.origin)
    checked.forEach((v) => url.searchParams.append("targets[]", v))
    this.linkTarget.href = url.pathname + url.search
  }
}
