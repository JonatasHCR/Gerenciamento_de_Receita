import { Controller } from "@hotwired/stimulus"

// Opções do Relatório de Movimentação. "Somente faturas em aberto" só faz
// sentido quando há seção de faturamento — no tipo "recebimento" o campo some
// (e é desmarcado, para não viajar no submit).
export default class extends Controller {
  static targets = ["tipo", "onlyOpen", "onlyOpenBox"]

  connect() {
    this.toggle()
  }

  toggle() {
    const tipo = this.tipoTargets.find((radio) => radio.checked)?.value
    const hide = tipo === "recebimento"

    this.onlyOpenTarget.hidden = hide
    if (hide) this.onlyOpenBoxTarget.checked = false
  }
}
