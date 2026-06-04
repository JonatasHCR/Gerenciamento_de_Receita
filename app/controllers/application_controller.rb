class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Method

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :set_paper_trail_whodunnit

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  PT_MONTHS = %w[JANEIRO FEVEREIRO MARÇO ABRIL MAIO JUNHO JULHO AGOSTO SETEMBRO OUTUBRO NOVEMBRO DEZEMBRO].freeze

  def pt_month_year(date = Date.current)
    "#{PT_MONTHS[date.month - 1]}/#{date.year}"
  end
  helper_method :pt_month_year

  # "06/2026" → "Jun/2026" em português abreviado para os gráficos
  def pt_month_label(mm_yyyy)
    parts = mm_yyyy.split("/")
    abbrev = PT_MONTHS[parts[0].to_i - 1].capitalize.first(3)
    "#{abbrev}/#{parts[1]}"
  end
  helper_method :pt_month_label

  def set_paper_trail_whodunnit
    PaperTrail.request.whodunnit = current_user&.id&.to_s
  end

  def user_not_authorized
    flash[:alert] = "Você não tem permissão para realizar esta ação."
    redirect_back_or_to root_path
  end
end
