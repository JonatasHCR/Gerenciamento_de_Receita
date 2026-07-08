import { Controller } from "@hotwired/stimulus"

// Monta a URL de geração a partir do form; "Pré-visualizar" carrega o PDF na iframe,
// e os links de download (Word/PDF) apontam para a mesma URL sem preview.
export default class extends Controller {
  static targets = ["frame", "wordLink", "pdfLink", "kind", "invoice", "inicio", "fim"]
  static values = { url: String }

  connect() { this.update() }

  params() {
    const p = new URLSearchParams()
    p.set("kind", this.kindTarget.value)
    if (this.invoiceTarget.value) p.set("invoice_id", this.invoiceTarget.value)
    if (this.inicioTarget.value) p.set("periodo_inicio", this.inicioTarget.value)
    if (this.fimTarget.value) p.set("periodo_fim", this.fimTarget.value)
    return p
  }

  update() {
    const word = this.params(); word.set("output", "docx")
    const pdf = this.params(); pdf.set("output", "pdf")
    this.wordLinkTarget.href = `${this.urlValue}?${word}`
    this.pdfLinkTarget.href = `${this.urlValue}?${pdf}`
  }

  preview() {
    const p = this.params()
    p.set("output", "pdf")
    p.set("preview", "1")
    this.frameTarget.src = `${this.urlValue}?${p}`
  }
}
