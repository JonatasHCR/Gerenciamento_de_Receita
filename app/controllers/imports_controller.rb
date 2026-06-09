class ImportsController < ApplicationController
  def new
    authorize :import, :new?
  end

  def template
    authorize :import, :new?
    xlsx_data = Imports::TemplateGenerator.new.call
    send_data xlsx_data,
      filename: "modelo_importacao.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
  end

  ALLOWED_UPLOAD_EXTENSIONS = %w[.xlsx .xls].freeze
  MAX_UPLOAD_BYTES = 10.megabytes

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

    result = Imports::ExcelImporter.new(file.path).call

    if !result.success?
      # Erro fatal: arquivo não pôde ser processado.
      @errors        = result.errors
      @fatal_error   = result.fatal_error
      @import_count  = result.imported
      flash.now[:alert] = result.fatal_error
      render :new, status: :unprocessable_entity
    elsif result.fully_clean?
      redirect_to root_path,
        notice: "Importação concluída: #{result.imported} registro(s) importado(s)."
    else
      # Sucesso parcial: registros válidos foram gravados; linhas com erro listadas.
      @errors       = result.errors
      @import_count = result.imported
      render :new, status: :unprocessable_entity
    end
  end

  private

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
