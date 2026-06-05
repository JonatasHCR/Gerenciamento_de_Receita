require "rails_helper"

RSpec.describe Imports::TemplateGenerator do
  after { Dir.glob(Rails.root.join("tmp", "tmpl_*.xlsx")).each { |f| File.delete(f) } }

  it "gera um .xlsx com as quatro abas esperadas" do
    data = described_class.new.call
    expect(data).to be_present

    path = Rails.root.join("tmp", "tmpl_#{SecureRandom.hex(4)}.xlsx").to_s
    File.binwrite(path, data)
    wb = Roo::Spreadsheet.open(path)
    expect(wb.sheets).to include(
      "CADASTRO CENTRO DE CUSTO", "PREVISAO FATURAMENTO", "FATURAMENTO", "RECEBIMENTO"
    )
  end

  it "o modelo gerado é importável de ponta a ponta (round-trip)" do
    path = Rails.root.join("tmp", "tmpl_#{SecureRandom.hex(4)}.xlsx").to_s
    File.binwrite(path, described_class.new.call)

    result = Imports::ExcelImporter.new(path).call

    expect(result.fatal_error).to be_nil
    expect(result.errors).to be_empty
    expect(result.created).to be > 0

    cc = CostCenter.find_by(cr_code: "4452")
    expect(cc).to be_present
    expect(cc.contract_number).to eq("055/2025")
    expect(cc.value).to eq(500_000)
    expect(cc.coordinator_list).to eq(["Coordenador A", "Gestor B"])
    expect(cc.participation).to eq(1.0) # 100% no modelo → 1,0

    inv = Invoice.find_by(number: "12345")
    expect(inv).to be_present
    expect(inv.principal?).to be(true)
    expect(inv.client_name).to eq(cc.client.name) # cliente derivado do CR

    month_year = ForecastEntry.month_year_for(Date.current)
    fe = ForecastEntry.find_by(cost_center: cc, month_year: month_year)
    expect(fe).to be_present
    expect(fe.forecasted_total).to eq(270_000)
  end
end
