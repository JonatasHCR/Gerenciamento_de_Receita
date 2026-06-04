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
    if result.success?
      redirect_to root_path, notice: "Importação concluída com sucesso."
    else
      @errors = result.errors
      render :new, status: :unprocessable_entity
    end
  end
end
