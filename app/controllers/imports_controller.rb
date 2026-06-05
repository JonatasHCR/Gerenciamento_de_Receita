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

  def create
    authorize :import, :create?
    file = params[:file]
    unless file
      redirect_to new_import_path, alert: "Selecione um arquivo."
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
end
