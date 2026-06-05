require "rails_helper"
require "caxlsx"

RSpec.describe Imports::ExcelImporter do
  # Monta um .xlsx no layout real (0-indexed por coluna, igual ao MODELO).
  def build_xlsx(cost_center_rows: [], forecast_rows: [], invoice_rows: [],
                 receipt_rows: [], month_year: "JUNHO/2026", omit_sheets: [])
    pkg = Axlsx::Package.new
    wb  = pkg.workbook

    unless omit_sheets.include?(:cost_centers)
      wb.add_worksheet(name: "CADASTRO CENTRO DE CUSTO") do |s|
        s.add_row ["CADASTRO"]; s.add_row []; s.add_row []
        s.add_row ["CR", "PART.", "DESCRIÇÃO", "CLIENTE"]          # linha 4
        cost_center_rows.each { |r| s.add_row(r) }                  # linha 5+
      end
    end

    unless omit_sheets.include?(:forecasts)
      wb.add_worksheet(name: "PREVISAO FATURAMENTO") do |s|
        s.add_row ["PREVISAO"]; s.add_row []
        s.add_row ["", "", "", "", "", "", "", "", month_year]      # I3 = mês/ano
        s.add_row ["ORD","CR","PART","OBJETO","DESCRIÇÃO","CLIENTE","DATA FINAL","COORDENADOR","","PREVISTO","%UFC","REALIZADO","%UFCR"]
        s.add_row []                                                 # linha 5
        forecast_rows.each { |r| s.add_row(r) }                      # linha 6+
      end
    end

    unless omit_sheets.include?(:invoices)
      wb.add_worksheet(name: "FATURAMENTO") do |s|
        s.add_row ["FATURAMENTO"]; s.add_row []; s.add_row []
        s.add_row ["CENTRO DE CUSTO","NOTA FISCAL","CR","CLIENTE","DATA EMISSÃO","VALOR","MÊS EMISSÃO","OBSERVAÇÃO"]
        s.add_row []                                                          # linha 5
        invoice_rows.each { |r| s.add_row(r) }                                # linha 6+
      end
    end

    unless omit_sheets.include?(:receipts)
      wb.add_worksheet(name: "RECEBIMENTO") do |s|
        s.add_row ["RECEBIMENTO"]; s.add_row []; s.add_row []
        s.add_row ["NOTA FISCAL","CENTRO DE CUSTO","CLIENTE","DATA BAIXA","RECEBIDO NO MÊS","MÊS BAIXA","OBSERVAÇÃO"]
        s.add_row []                                                 # linha 5
        receipt_rows.each { |r| s.add_row(r) }                       # linha 6+
      end
    end

    path = Rails.root.join("tmp", "import_test_#{SecureRandom.hex(4)}.xlsx").to_s
    pkg.serialize(path)
    path
  end

  # CADASTRO: [CR, PART, DESCRIÇÃO, CLIENTE]
  def cc_row(cr:, desc:, client: "Cliente Teste", part: 1.0) = [cr, part, desc, client]
  # FATURAMENTO: [CENTRO, NF, CR, CLIENTE, DATA, VALOR, MÊS, OBS]
  def inv_row(nf:, cr:, value:, date: Date.new(2026, 6, 10), client: "X", obs: "") = ["", nf, cr, client, date, value, "", obs]

  after { Dir.glob(Rails.root.join("tmp", "import_test_*.xlsx")).each { |f| File.delete(f) } }

  it "importa linhas válidas e continua mesmo com uma inválida" do
    path = build_xlsx(cost_center_rows: [
      cc_row(cr: "CR-OK1", desc: "Contrato A"),
      cc_row(cr: "CR-BAD", desc: ""),     # descrição e cliente vazios → pulada (seção)
      cc_row(cr: "CR-OK2", desc: "Contrato B")
    ])
    result = described_class.new(path).call

    expect(result.success?).to be(true)
    expect(CostCenter.where(cr_code: %w[CR-OK1 CR-OK2]).count).to eq(2)
  end

  it "enriquece o CC com objeto, data final e MÚLTIPLOS coordenadores da PREVISÃO" do
    path = build_xlsx(
      cost_center_rows: [cc_row(cr: "CR-1", desc: "Desc A", client: "ACME")],
      forecast_rows: [
        [1, "CR-1", 1.0, "Objeto do contrato", "Desc A", "ACME",
         Date.new(2027, 1, 5), "Ana Maria / Dr. João", "", 100_000, 1.0, 0, 0]
      ]
    )
    described_class.new(path).call
    cc = CostCenter.find_by(cr_code: "CR-1")

    expect(cc.object_text).to eq("Objeto do contrato")
    expect(cc.end_date).to eq(Date.new(2027, 1, 5))
    expect(cc.coordinator_list).to eq(["Ana Maria", "Dr. João"])
    expect(ForecastEntry.find_by(cost_center: cc, month_year: "JUNHO/2026")).to be_present
  end

  it "importa observações do faturamento" do
    path = build_xlsx(
      cost_center_rows: [cc_row(cr: "CR-1", desc: "Desc A")],
      invoice_rows: [inv_row(nf: "NF1", cr: "CR-1", value: 1000, obs: "pago adiantado")]
    )
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
    path = build_xlsx(
      cost_center_rows: [cc_row(cr: "CR-1", desc: "Desc A")],
      invoice_rows: [
        inv_row(nf: "NF1", cr: "CR-1", value: 1000),
        inv_row(nf: "NF2", cr: "CR-X", value: 500)
      ]
    )
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
