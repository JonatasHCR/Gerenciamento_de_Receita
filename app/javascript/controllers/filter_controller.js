import { Controller } from "@hotwired/stimulus"

// Submete o formulário de filtros (com debounce) ao digitar na busca.
// Como envia o form inteiro, todos os filtros (mês, CC, situação) viajam juntos
// e atualizam o turbo_frame de resultados — sem resetar seleções.
export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  #timeout

  submit() {
    clearTimeout(this.#timeout)
    this.#timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }
}
