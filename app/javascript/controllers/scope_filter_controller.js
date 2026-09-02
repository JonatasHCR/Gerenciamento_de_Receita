import { Controller } from "@hotwired/stimulus"

// Filtro em CASCATA dos relatórios. O "Agrupar por" define a cadeia de níveis;
// cada nível só aparece depois que o anterior tem alguma seleção, e é estreitado
// pelo que foi marcado acima. Nível sem seleção = todos. Tudo no navegador —
// sem round-trip e sem turbo-frame (os forms são de download, data-turbo="false").
const CHAINS = {
  coordenador: ["coordenador", "cliente", "centro_custo"],
  cliente: ["cliente", "centro_custo"],
  centro_custo: ["centro_custo"]
}

const HINTS = {
  cliente: "Marque um coordenador acima para escolher clientes (nenhum = todos).",
  centro_custo: "Marque um cliente acima para escolher centros de custo (nenhum = todos)."
}

const TITLES = { coordenador: "coordenador", cliente: "cliente", centro_custo: "centro de custo" }

export default class extends Controller {
  static targets = ["groupBy", "level"]
  static values = { groupBy: String }

  connect() {
    this.refresh()
  }

  groupChanged() {
    // Trocar a dimensão zera as seleções — a cadeia é outra.
    this.levelTargets.forEach((level) => this.#items(level).forEach((i) => (i.checked = false)))
    this.refresh()
  }

  selectAll(event) {
    this.#visibleItems(event.target.closest("[data-scope-filter-target=level]")).forEach((label) => {
      label.querySelector("input[type=checkbox]").checked = true
    })
    this.refresh()
  }

  selectNone(event) {
    this.#items(event.target.closest("[data-scope-filter-target=level]")).forEach((i) => (i.checked = false))
    this.refresh()
  }

  refresh() {
    const chain = CHAINS[this.#groupBy()] || CHAINS.cliente
    const selected = { coordenador: [], cliente: [] }

    this.levelTargets.forEach((level) => {
      const name = level.dataset.level
      const position = chain.indexOf(name)

      if (position === -1) {
        // Nível fora da cadeia: some e não filtra nada.
        level.hidden = true
        this.#items(level).forEach((i) => (i.checked = false))
        return
      }

      level.hidden = false
      level.style.order = position

      // Só libera o nível quando o anterior da cadeia já tem seleção.
      const previous = chain[position - 1]
      const locked = previous !== undefined && selected[previous].length === 0

      this.#toggleBody(level, locked, previous)
      if (locked) {
        this.#items(level).forEach((i) => (i.checked = false))
      } else {
        this.#narrow(level, selected)
      }

      if (name in selected) selected[name] = this.#checkedValues(level)
    })
  }

  // --- internos -------------------------------------------------------------

  #groupBy() {
    return this.hasGroupByTarget ? this.groupByTarget.value : this.groupByValue
  }

  #toggleBody(level, locked, previous) {
    const body = level.querySelector("[data-role=body]")
    const hint = level.querySelector("[data-role=hint]")
    body.hidden = locked
    hint.hidden = !locked
    if (locked) hint.textContent = HINTS[level.dataset.level] || `Selecione um ${TITLES[previous]} acima.`
  }

  // Aplica o estreitamento pela seleção dos níveis anteriores + a busca.
  #narrow(level, selected) {
    const search = this.#normalize(level.querySelector("[data-role=search]")?.value || "")
    let visible = 0

    this.#labels(level).forEach((label) => {
      const box = label.querySelector("input[type=checkbox]")
      const matchesScope = this.#matchesScope(label, selected)
      const matchesSearch = search === "" || this.#normalize(label.textContent).includes(search)

      // display direto (e não a classe .hidden do Tailwind) para não depender
      // de a classe existir no CSS gerado.
      label.style.display = matchesScope && matchesSearch ? "" : "none"
      if (!matchesScope) box.checked = false
      if (matchesScope && matchesSearch) visible++
    })

    const total = this.#labels(level).length
    level.querySelector("[data-role=count]").textContent =
      visible === total ? `${total}` : `${visible} de ${total}`
    level.querySelector("[data-role=empty]").hidden = visible > 0
  }

  #matchesScope(label, selected) {
    if (selected.coordenador.length > 0) {
      const names = JSON.parse(label.dataset.coordinators || "[]")
      if (!names.some((n) => selected.coordenador.includes(n))) return false
    }
    if (selected.cliente.length > 0 && label.dataset.clientId !== undefined) {
      if (!selected.cliente.includes(label.dataset.clientId)) return false
    }
    return true
  }

  #labels(level) {
    return Array.from(level.querySelectorAll("[data-role=item]"))
  }

  #items(level) {
    return Array.from(level.querySelectorAll("[data-role=item] input[type=checkbox]"))
  }

  #visibleItems(level) {
    return this.#labels(level).filter((l) => l.style.display !== "none")
  }

  #checkedValues(level) {
    return this.#items(level).filter((i) => i.checked).map((i) => i.value)
  }

  #normalize(text) {
    return text.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase().trim()
  }
}
