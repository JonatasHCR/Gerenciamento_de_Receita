import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "backdrop", "label", "icon", "logoLink", "headerEl"]

  connect() {
    // Restore desktop collapsed state
    if (localStorage.getItem("sidebar_collapsed") === "true") {
      this.#applyCollapse(true, false)
    }
    // Close mobile sidebar on Turbo navigation
    this._closeOnNav = () => this.#closeMobile()
    document.addEventListener("turbo:before-visit", this._closeOnNav)
  }

  disconnect() {
    document.removeEventListener("turbo:before-visit", this._closeOnNav)
  }

  // ── Mobile overlay ──────────────────────────────────────────────────────────
  mobileToggle() {
    const isOpen = this.sidebarTarget.dataset.mobileOpen === "true"
    isOpen ? this.#closeMobile() : this.#openMobile()
  }

  mobileClose() { this.#closeMobile() }

  // ── Desktop collapse ────────────────────────────────────────────────────────
  toggle() {
    const collapsed = this.element.dataset.sidebarCollapsed === "true"
    this.#applyCollapse(!collapsed, true)
    localStorage.setItem("sidebar_collapsed", String(!collapsed))
  }

  // ── Private ─────────────────────────────────────────────────────────────────
  #openMobile() {
    this.sidebarTarget.dataset.mobileOpen = "true"
    this.sidebarTarget.classList.remove("-translate-x-full")
    this.sidebarTarget.classList.add("translate-x-0")
    if (this.hasBackdropTarget) this.backdropTarget.classList.remove("hidden")
  }

  #closeMobile() {
    if (!this.hasSidebarTarget) return
    this.sidebarTarget.dataset.mobileOpen = "false"
    this.sidebarTarget.classList.add("-translate-x-full")
    this.sidebarTarget.classList.remove("translate-x-0")
    if (this.hasBackdropTarget) this.backdropTarget.classList.add("hidden")
  }

  #applyCollapse(collapsed, animate = true) {
    this.element.dataset.sidebarCollapsed = collapsed
    const sidebar = this.sidebarTarget

    if (!animate) sidebar.classList.add("!transition-none")

    if (collapsed) {
      sidebar.classList.remove("lg:w-60")
      sidebar.classList.add("lg:w-16")
    } else {
      sidebar.classList.remove("lg:w-16")
      sidebar.classList.add("lg:w-60")
    }

    this.labelTargets.forEach(el => el.classList.toggle("hidden", collapsed))
    if (this.hasIconTarget) this.iconTarget.classList.toggle("rotate-180", collapsed)
    if (this.hasLogoLinkTarget) this.logoLinkTarget.classList.toggle("hidden", collapsed)

    if (this.hasHeaderElTarget) {
      this.headerElTarget.classList.toggle("justify-between", !collapsed)
      this.headerElTarget.classList.toggle("justify-center", collapsed)
    }

    if (!animate) {
      requestAnimationFrame(() => sidebar.classList.remove("!transition-none"))
    }
  }
}
