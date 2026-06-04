import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["costCenter", "clientName"]
  static values  = { map: Object }

  fill() {
    const id = this.costCenterTarget.value
    if (!id) return
    const name = this.mapValue[id]
    if (name) this.clientNameTarget.value = name
  }
}
