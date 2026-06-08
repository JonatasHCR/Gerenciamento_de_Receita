module ApplicationHelper
  SIDEBAR_BASE = "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors w-full"

  def sidebar_nav_class(path)
    active = path == root_path ? current_page?(path) : request.path.start_with?(path)
    active \
      ? "#{SIDEBAR_BASE} bg-red-50 text-red-700" \
      : "#{SIDEBAR_BASE} text-gray-600 hover:bg-red-50 hover:text-red-700"
  end

  def nav_link_to(label, path, **opts)
    active = current_page?(path)
    css = active \
      ? "px-3 py-2 rounded-md text-sm font-medium text-red-700 bg-red-50" \
      : "px-3 py-2 rounded-md text-sm font-medium text-gray-600 hover:text-red-700 hover:bg-red-50 transition-colors"
    link_to label, path, class: css, **opts
  end

  def role_badge_class(role)
    case role.to_s
    when "admin"       then "bg-red-100 text-red-800"
    when "financeiro"  then "bg-orange-100 text-orange-700"
    when "gestor"      then "bg-green-100 text-green-700"
    when "coordenador" then "bg-yellow-100 text-yellow-700"
    else "bg-gray-100 text-gray-700"
    end
  end

  PT_MONTH_NAMES = %w[JANEIRO FEVEREIRO MARÇO ABRIL MAIO JUNHO JULHO AGOSTO SETEMBRO OUTUBRO NOVEMBRO DEZEMBRO].freeze

  def month_year_to_input(month_year)
    parts = month_year.to_s.split("/")
    return "" unless parts.size == 2
    idx = PT_MONTH_NAMES.index(parts[0].upcase)
    return "" unless idx
    format("%04d-%02d", parts[1].to_i, idx + 1)
  end

  # Rótulo com asterisco indicando campo obrigatório.
  def req(text)
    safe_join([text, " ", tag.span("*", class: "text-red-500", title: "Campo obrigatório")])
  end

  def brl(value)
    number_to_currency(value, unit: "R$ ", separator: ",", delimiter: ".", precision: 2)
  end

  def payment_status_badge(invoice)
    case invoice.payment_status
    when :paid
      tag.span "Quitado", class: "px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-700"
    when :partial
      tag.span "Parcial", class: "px-2 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-700"
    else
      tag.span "Não pago", class: "px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-700"
    end
  end

  MONEY_LABEL_CLASS = "block text-sm font-medium text-gray-700 mb-1".freeze
  MONEY_INPUT_CLASS = "w-full rounded-lg border border-gray-300 pl-9 pr-3 py-2 text-sm focus:ring-2 focus:ring-red-500".freeze

  # Campo de valor em R$ com máscara (Stimulus "currency"): o usuário vê/edita
  # "50.000,00" (digitando ou colando) e o servidor recebe o número cru via hidden.
  def money_field(form, method, label_text, required: true, **hidden_opts)
    label  = form.label(method, required ? req(label_text) : label_text, class: MONEY_LABEL_CLASS)
    hidden = form.hidden_field(method, data: { "currency-target": "input" }, **hidden_opts)
    money_field_wrapper(label, hidden, form.object&.public_send(method))
  end

  # Variante para campos fora de form builder (usa hidden_field_tag).
  def money_field_tag(name, value, label_text, required: true)
    label  = label_tag(name, required ? req(label_text) : label_text, class: MONEY_LABEL_CLASS)
    hidden = hidden_field_tag(name, value, data: { "currency-target": "input" })
    money_field_wrapper(label, hidden, value)
  end

  # Campo de senha com botão "ver senha" (Stimulus "password-reveal").
  def password_field_with_toggle(form, method, label_html, autocomplete:, autofocus: false)
    tag.div(data: { controller: "password-reveal" }) do
      safe_join([
        form.label(method, label_html, class: MONEY_LABEL_CLASS),
        tag.div(class: "relative") do
          safe_join([
            form.password_field(method, autocomplete: autocomplete, autofocus: autofocus,
              class: "w-full rounded-lg border border-gray-300 pl-3 pr-10 py-2 text-sm focus:ring-2 focus:ring-red-500",
              data: { "password-reveal-target": "field" }),
            reveal_password_button
          ])
        end
      ])
    end
  end

  private

  def money_field_wrapper(label_html, hidden_html, current_value)
    display = if current_value.present? && current_value.to_d != 0
                number_to_currency(current_value, unit: "", delimiter: ".", separator: ",").strip
    else
                ""
    end

    tag.div(data: { controller: "currency" }) do
      safe_join([
        label_html,
        tag.div(class: "relative") do
          safe_join([
            tag.span("R$", class: "absolute inset-y-0 left-3 flex items-center text-sm text-gray-500 pointer-events-none"),
            tag.input(type: "text", value: display, inputmode: "numeric", placeholder: "0,00", autocomplete: "off",
                      class: MONEY_INPUT_CLASS,
                      data: { "currency-target": "display", action: "input->currency#format" }),
            hidden_html
          ])
        end
      ])
    end
  end

  def reveal_password_button
    tag.button(type: "button", tabindex: "-1",
      class: "absolute inset-y-0 right-2 flex items-center text-gray-400 hover:text-gray-600 cursor-pointer",
      data: { action: "password-reveal#toggle" }) do
      safe_join([
        # Olho aberto (visível quando a senha está oculta — clique para mostrar).
        tag.svg(xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24",
                "stroke-width": "1.5", stroke: "currentColor", class: "w-5 h-5",
                data: { "password-reveal-target": "eye" }) do
          safe_join([
            tag.path("stroke-linecap": "round", "stroke-linejoin": "round",
                     d: "M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z"),
            tag.path("stroke-linecap": "round", "stroke-linejoin": "round",
                     d: "M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z")
          ])
        end,
        # Olho cortado (visível quando a senha está visível — clique para ocultar).
        tag.svg(xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24",
                "stroke-width": "1.5", stroke: "currentColor", class: "w-5 h-5 hidden",
                data: { "password-reveal-target": "eyeSlash" }) do
          tag.path("stroke-linecap": "round", "stroke-linejoin": "round",
                   d: "M3.98 8.223A10.477 10.477 0 0 0 1.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.451 10.451 0 0 1 12 4.5c4.756 0 8.773 3.162 10.065 7.498a10.522 10.522 0 0 1-4.293 5.774M6.228 6.228 3 3m3.228 3.228 3.65 3.65m7.894 7.894L21 21m-3.228-3.228-3.65-3.65m0 0a3 3 0 1 0-4.243-4.243m4.243 4.243L9.88 9.88")
        end
      ])
    end
  end
end
