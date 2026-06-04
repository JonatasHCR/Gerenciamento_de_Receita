import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label", "icon", "logoLink", "headerEl"]

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
      if (this.hasLogoLinkTarget) this.logoLinkTarget.classList.add("hidden")
      if (this.hasHeaderElTarget) {
        this.headerElTarget.classList.remove("justify-between")
        this.headerElTarget.classList.add("justify-center")
      }
    } else {
      this.element.classList.remove("w-16")
      this.element.classList.add("w-60")
      this.labelTargets.forEach(el => el.classList.remove("hidden"))
      this.iconTarget.classList.remove("rotate-180")
      if (this.hasLogoLinkTarget) this.logoLinkTarget.classList.remove("hidden")
      if (this.hasHeaderElTarget) {
        this.headerElTarget.classList.remove("justify-center")
        this.headerElTarget.classList.add("justify-between")
      }
    }
  }
}
