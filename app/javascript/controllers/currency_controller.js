import { Controller } from "@hotwired/stimulus"

// Máscara de moeda (R$). O input visível mostra "50.000,00" enquanto o usuário
// digita OU cola; um hidden field guarda o valor cru ("50000.00") que o servidor
// (Rails/decimal) consegue parsear. Os dígitos são tratados como centavos.
export default class extends Controller {
  static targets = ["display", "input"]

  connect() {
    const raw = parseFloat(String(this.inputTarget.value).replace(",", "."))
    if (!isNaN(raw) && raw !== 0) {
      this.inputTarget.value = raw.toFixed(2)
      this.displayTarget.value = this.formatBR(raw)
    } else {
      this.displayTarget.value = ""
    }
  }

  // O evento "input" cobre digitação e colagem (paste dispara input).
  format() {
    const digits = this.displayTarget.value.replace(/\D/g, "")
    if (digits === "") {
      this.displayTarget.value = ""
      this.inputTarget.value = ""
      return
    }
    const number = parseInt(digits, 10) / 100
    this.displayTarget.value = this.formatBR(number)
    this.inputTarget.value = number.toFixed(2)
  }

  formatBR(number) {
    return number.toLocaleString("pt-BR", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    })
  }
}
