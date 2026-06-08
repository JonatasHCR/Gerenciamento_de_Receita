require "rails_helper"
require "caxlsx"

RSpec.describe Imports::ExcelImporter do
  # Monta um .xlsx no layout limpo (detecção por cabeçalho).
  def build_xlsx(cost_center_rows: [], forecast_rows: [], invoice_rows: [],
                 receipt_rows: [], omit_sheets: [])
    pkg = Axlsx::Package.new
    wb  = pkg.workbook

    unless omit_sheets.include?(:cost_centers)
      wb.add_worksheet(name: "CADASTRO CENTRO DE CUSTO") do |s|
        s.add_row ["CADASTRO"]; s.add_row []; s.add_row []
        s.add_row ["CR", "PART. (%)", "DESCRIÇÃO", "CLIENTE", "OBJETO", "DATA FINAL", "COORDENADOR"]
        cost_center_rows.each { |r| s.add_row(r) }
      end
    end

    unless omit_sheets.include?(:forecasts)
      wb.add_worksheet(name: "PREVISAO FATURAMENTO") do |s|
        s.add_row ["PREVISAO"]; s.add_row []; s.add_row []
        s.add_row ["CR", "MÊS/ANO", "PREVISTO", "OBSERVAÇÃO"]
        forecast_rows.each { |r| s.add_row(r) }
      end
    end

    unless omit_sheets.include?(:invoices)
      wb.add_worksheet(name: "FATURAMENTO") do |s|
        s.add_row ["FATURAMENTO"]; s.add_row []; s.add_row []
        s.add_row ["NOTA FISCAL", "CR", "CLIENTE", "DATA EMISSÃO", "VALOR", "OBSERVAÇÃO"]
        invoice_rows.each { |r| s.add_row(r) }
      end
    end

    unless omit_sheets.include?(:receipts)
      wb.add_worksheet(name: "RECEBIMENTO") do |s|
        s.add_row ["RECEBIMENTO"]; s.add_row []; s.add_row []
        s.add_row ["NOTA FISCAL", "CR", "DATA BAIXA", "RECEBIDO NO MÊS", "OBSERVAÇÃO"]
        receipt_rows.each { |r| s.add_row(r) }
      end
    end

    path = Rails.root.join("tmp", "import_test_#{SecureRandom.hex(4)}.xlsx").to_s
    pkg.serialize(path)
    path
  end

  # CADASTRO: [CR, PART(%), DESCRIÇÃO, CLIENTE, OBJETO, DATA FINAL, COORDENADOR]
  def cc_row(cr:, desc:, client: "Cliente Teste", part: 100, objeto: "", data_final: nil, coord: "")
    [cr, part, desc, client, objeto, data_final, coord]
  end
  # FATURAMENTO: [NF, CR, CLIENTE, DATA, VALOR, OBS]
  def inv_row(nf:, cr:, value:, date: Date.new(2026, 6, 10), client: "X", obs: "") = [nf, cr, client, date, value, obs]

  after { Dir.glob(Rails.root.join("tmp", "import_test_*.xlsx")).each { |f| File.delete(f) } }

  it "importa CCs válidos e pula linhas de seção" do
    path = build_xlsx(cost_center_rows: [
      cc_row(cr: "CR-OK1", desc: "Contrato A"),
      cc_row(cr: "CR-BAD", desc: "", client: ""),  # sem descrição e cliente → pulada
      cc_row(cr: "CR-OK2", desc: "Contrato B")
    ])
    described_class.new(path).call
    expect(CostCenter.where(cr_code: %w[CR-OK1 CR-OK2]).count).to eq(2)
    expect(CostCenter.find_by(cr_code: "CR-BAD")).to be_nil
  end

  it "grava objeto, data final e múltiplos coordenadores no CADASTRO; participação em %" do
    path = build_xlsx(cost_center_rows: [
      cc_row(cr: "CR-1", desc: "Desc A", client: "ACME", part: 75,
             objeto: "Objeto do contrato", data_final: Date.new(2027, 1, 5),
             coord: "Ana Maria / Dr. João")
    ])
    described_class.new(path).call
    cc = CostCenter.find_by(cr_code: "CR-1")

    expect(cc.object_text).to eq("Objeto do contrato")
    expect(cc.end_date).to eq(Date.new(2027, 1, 5))
    expect(cc.coordinator_list).to eq(["Ana Maria", "Dr. João"])
    expect(cc.participation).to eq(0.75) # 75% → 0,75
  end

  it "cria previsão com CR + mês numérico (06/2025) + previsto + observação" do
    create(:cost_center, cr_code: "CR-1")
    path = build_xlsx(forecast_rows: [["CR-1", "06/2025", 50_000, "obs da previsão"]])
    described_class.new(path).call

    fe = ForecastEntry.find_by(cost_center: CostCenter.find_by(cr_code: "CR-1"), month_year: "JUNHO/2025")
    expect(fe).to be_present
    expect(fe.forecasted_total).to eq(50_000)
    expect(fe.observations).to eq("obs da previsão")
  end

  it "importa previsões de meses diferentes cada uma no seu mês (não colapsa)" do
    create(:cost_center, cr_code: "CR-1")
    path = build_xlsx(forecast_rows: [
      ["CR-1", "06/2026", 100_000, ""],
      ["CR-1", "07/2026", 110_000, ""]
    ])
    described_class.new(path).call

    cc = CostCenter.find_by(cr_code: "CR-1")
    expect(ForecastEntry.find_by(cost_center: cc, month_year: "JUNHO/2026")&.forecasted_total).to eq(100_000)
    expect(ForecastEntry.find_by(cost_center: cc, month_year: "JULHO/2026")&.forecasted_total).to eq(110_000)
  end

  it "cria previsão quando o mês/ano vem como Date (célula formatada como data)" do
    create(:cost_center, cr_code: "CR-1")
    # Excel formatado como data → roo entrega um Date; deve cair em JUNHO/2025.
    path = build_xlsx(forecast_rows: [["CR-1", Date.new(2025, 6, 1), 50_000, ""]])
    described_class.new(path).call

    fe = ForecastEntry.find_by(cost_center: CostCenter.find_by(cr_code: "CR-1"), month_year: "JUNHO/2025")
    expect(fe).to be_present
    expect(fe.forecasted_total).to eq(50_000)
  end

  it "sinaliza previsão de CR não cadastrado" do
    path = build_xlsx(forecast_rows: [["CR-X", "06/2025", 1000, ""]])
    result = described_class.new(path).call
    expect(result.errors.any? { |e| e.include?("CR-X") }).to be(true)
  end

  it "importa observações do faturamento" do
    create(:cost_center, cr_code: "CR-1")
    path = build_xlsx(invoice_rows: [inv_row(nf: "NF1", cr: "CR-1", value: 1000, obs: "pago adiantado")])
    described_class.new(path).call
    expect(Invoice.find_by(number: "NF1").observations).to eq("pago adiantado")
  end

  it "atualiza registros existentes na reimportação (upsert)" do
    cc = create(:cost_center, cr_code: "CR-UP", description: "Antiga")
    path = build_xlsx(cost_center_rows: [cc_row(cr: "CR-UP", desc: "Nova Descrição", client: cc.client.name)])
    result = described_class.new(path).call
    expect(result.updated).to be >= 1
    expect(cc.reload.description).to eq("Nova Descrição")
  end

  it "sinaliza faturamento cujo CC não existe, sem abortar" do
    create(:cost_center, cr_code: "CR-1")
    path = build_xlsx(invoice_rows: [
      inv_row(nf: "NF1", cr: "CR-1", value: 1000),
      inv_row(nf: "NF2", cr: "CR-X", value: 500)
    ])
    result = described_class.new(path).call
    expect(Invoice.find_by(number: "NF1")).to be_present
    expect(Invoice.find_by(number: "NF2")).to be_nil
    expect(result.errors.any? { |e| e.include?("CR-X") }).to be(true)
  end

  it "não aborta quando uma aba está ausente" do
    path = build_xlsx(cost_center_rows: [cc_row(cr: "CR-1", desc: "Desc A")], omit_sheets: [:receipts])
    result = described_class.new(path).call
    expect(CostCenter.find_by(cr_code: "CR-1")).to be_present
    expect(result.errors.any? { |e| e.include?("RECEBIMENTO") }).to be(true)
  end

  it "retorna erro fatal quando o arquivo não pode ser aberto" do
    result = described_class.new("/caminho/inexistente.xlsx").call
    expect(result.success?).to be(false)
    expect(result.fatal_error).to be_present
  end
end
