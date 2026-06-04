import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label", "icon"]

  connect() {
    if (localStorage.getItem("sidebar_collapsed") === "true") {
      this.#apply(true)
    }
  }

  toggle() {
    const collapsed = this.element.dataset.sidebarCollapsed === "true"
    this.#apply(!collapsed)
    localStorage.setItem("sidebar_collapsed", String(!collapsed))
  }

  #apply(collapsed) {
    this.element.dataset.sidebarCollapsed = collapsed
    if (collapsed) {
      this.element.classList.remove("w-60")
      this.element.classList.add("w-16")
      this.labelTargets.forEach(el => el.classList.add("hidden"))
      this.iconTarget.classList.add("rotate-180")
    } else {
      this.element.classList.remove("w-16")
      this.element.classList.add("w-60")
      this.labelTargets.forEach(el => el.classList.remove("hidden"))
      this.iconTarget.classList.remove("rotate-180")
    }
  }
}
