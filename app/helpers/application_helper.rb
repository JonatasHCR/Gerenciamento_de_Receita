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
end
