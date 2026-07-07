class ImportsController < ApplicationController
  def new
    authorize :import, :new?
  end

  def template
    authorize :import, :new?
    xlsx_data = Imports::TemplateGenerator.new(only: template_sheets).call
    send_data xlsx_data,
      filename: "modelo_importacao.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
  end

  ALLOWED_UPLOAD_EXTENSIONS = %w[.xlsx .xls].freeze
  MAX_UPLOAD_BYTES = 10.megabytes

  # Alvos de negócio → aba do ExcelImporter. "usuarios" é tratado à parte (só admin).
  BUSINESS_TARGETS = {
    "centros"     => :cost_centers,
    "faturamento" => :invoices,
    "recebimento" => :receipts,
    "previsao"    => :forecasts
  }.freeze

  def create
    authorize :import, :create?
    file = params[:file]
    unless file.respond_to?(:original_filename)
      redirect_to new_import_path, alert: "Selecione um arquivo."
      return
    end

    if (erro = upload_error(file))
      redirect_to new_import_path, alert: erro
      return
    end

    targets       = Array(params[:targets])
    business      = targets & BUSINESS_TARGETS.keys
    import_users  = targets.include?("usuarios")
    authorize :import, :users? if import_users

    results = []
    # Sem alvo de negócio marcado (e sem usuários) = importação geral (todas as abas).
    only = business.map { |t| BUSINESS_TARGETS[t] }
    if business.any? || !import_users
      results << Imports::ExcelImporter.new(file.path, only: only.presence).call
    end
    results << Imports::UserImporter.new(file.path).call if import_users

    render_import_result(aggregate(results))
  end

  private

  # Abas do modelo conforme os alvos marcados (nil = todas). "usuarios" só p/ admin.
  def template_sheets
    targets = Array(params[:targets])
    return nil if targets.empty?

    sheets = targets.filter_map { |t| BUSINESS_TARGETS[t] }
    sheets << :users if targets.include?("usuarios") && current_user.admin?
    sheets.presence
  end

  # Combina os resultados dos importadores num único Result equivalente.
  def aggregate(results)
    Imports::ExcelImporter::Result.new(
      created:     results.sum(&:created),
      updated:     results.sum(&:updated),
      errors:      results.flat_map(&:errors),
      fatal_error: results.map(&:fatal_error).compact.first
    )
  end

  def render_import_result(result)
    if !result.success?
      @errors        = result.errors
      @fatal_error   = result.fatal_error
      @import_count  = result.imported
      flash.now[:alert] = result.fatal_error
      render :new, status: :unprocessable_entity
    elsif result.fully_clean?
      redirect_to root_path,
        notice: "Importação concluída: #{result.imported} registro(s) importado(s)."
    else
      @errors       = result.errors
      @import_count = result.imported
      render :new, status: :unprocessable_entity
    end
  end

  # Valida a planilha enviada antes de processá-la: só aceita extensões de Excel e
  # limita o tamanho (xlsx é um zip → evita zip-bomb/DoS). Retorna a mensagem de erro
  # ou nil se estiver ok.
  def upload_error(file)
    ext = File.extname(file.original_filename.to_s).downcase
    unless ALLOWED_UPLOAD_EXTENSIONS.include?(ext)
      return "Formato inválido. Envie uma planilha Excel (.xlsx ou .xls)."
    end
    if file.size.to_i > MAX_UPLOAD_BYTES
      return "Arquivo muito grande (máx. #{MAX_UPLOAD_BYTES / 1.megabyte} MB)."
    end
    nil
  end
end
