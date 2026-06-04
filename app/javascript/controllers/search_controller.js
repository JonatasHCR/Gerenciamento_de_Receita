import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "frame"]
  static values = { url: String, delay: { type: Number, default: 300 } }

  #timeout = null

  search() {
    clearTimeout(this.#timeout)
    this.#timeout = setTimeout(() => {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("q", this.inputTarget.value)
      this.frameTarget.src = url.toString()
    }, this.delayValue)
  }
}
