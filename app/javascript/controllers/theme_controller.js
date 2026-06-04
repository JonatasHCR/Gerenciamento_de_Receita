import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon"]

  connect() {
    this.update()
  }

  toggle() {
    const isDark = document.documentElement.classList.toggle("dark")
    localStorage.setItem("theme", isDark ? "dark" : "light")
    this.update()
  }

  update() {
    const isDark = document.documentElement.classList.contains("dark")
    if (this.hasIconTarget) {
      this.iconTarget.textContent = isDark ? "☀️" : "🌙"
    }
  }
}
