require "rails_helper"
require "caxlsx"

RSpec.describe Imports::ExcelImporter do
  # Gera um .xlsx temporário com as 4 abas esperadas. Por padrão as abas extras
  # ficam só com cabeçalhos; cada teste preenche as linhas que precisa.
  def build_xlsx(cost_center_rows: [], invoice_rows: [], omit_sheets: [])
    pkg = Axlsx::Package.new
    wb  = pkg.workbook

    unless omit_sheets.include?(:cost_centers)
      wb.add_worksheet(name: "CADASTRO CENTRO DE CUSTO") do |s|
        4.times { s.add_row [] }              # offset 4
        cost_center_rows.each { |r| s.add_row(r) }
      end
    end

    unless omit_sheets.include?(:invoices)
      wb.add_worksheet(name: "FATURAMENTO") do |s|
        5.times { s.add_row [] }              # offset 5
        invoice_rows.each { |r| s.add_row(r) }
      end
    end

    wb.add_worksheet(name: "RECEBIMENTO")          { |s| 5.times { s.add_row [] } } unless omit_sheets.include?(:receipts)
    wb.add_worksheet(name: "PREVISAO FATURAMENTO") { |s| 6.times { s.add_row [] } } unless omit_sheets.include?(:forecasts)

    path = Rails.root.join("tmp", "import_test_#{SecureRandom.hex(4)}.xlsx").to_s
    pkg.serialize(path)
    path
  end

  # Colunas CC: [0]=marcador, [1]=CR, [2]=part, [3]=descrição, [4]=cliente, [5]=, [6]=coord
  def cc_row(cr:, desc:, client: "Cliente Teste", part: 1.0)
    ["x", cr, part, desc, client, "", "Coordenador"]
  end

  after { Dir.glob(Rails.root.join("tmp", "import_test_*.xlsx")).each { |f| File.delete(f) } }

  it "importa as linhas válidas e continua mesmo com uma linha inválida" do
    path = build_xlsx(cost_center_rows: [
      cc_row(cr: "CR-OK1", desc: "Contrato A"),
      cc_row(cr: "CR-BAD", desc: ""),          # descrição vazia → inválido
      cc_row(cr: "CR-OK2", desc: "Contrato B")
    ])

    result = described_class.new(path).call

    expect(result.success?).to be(true)          # não houve erro fatal
    expect(result.partial?).to be(true)          # houve linha com erro
    expect(result.imported).to eq(2)             # as duas válidas entraram
    expect(CostCenter.where(cr_code: %w[CR-OK1 CR-OK2]).count).to eq(2)
    expect(CostCenter.find_by(cr_code: "CR-BAD")).to be_nil
    expect(result.errors.size).to eq(1)
    expect(result.errors.first).to include("CR-BAD")
    expect(result.errors.first).to match(/linha 6/)  # 4 cabeçalhos + 2ª linha de dados
  end

  it "sinaliza faturamento cujo centro de custo não existe, sem abortar" do
    path = build_xlsx(
      cost_center_rows: [cc_row(cr: "CR-OK1", desc: "Contrato A")],
      invoice_rows: [
        # [2]=NF, [3]=CR, [4]=cliente, [5]=data, [6]=valor
        ["", "", "NF1", "CR-OK1", "Cliente", Date.new(2026, 6, 10), 1000],
        ["", "", "NF2", "CR-INEXISTENTE", "Cliente", Date.new(2026, 6, 11), 500]
      ]
    )

    result = described_class.new(path).call

    expect(result.imported).to eq(2)             # 1 CC + 1 NF válida
    expect(Invoice.find_by(number: "NF1")).to be_present
    expect(Invoice.find_by(number: "NF2")).to be_nil
    expect(result.errors.any? { |e| e.include?("CR-INEXISTENTE") }).to be(true)
  end

  it "não aborta quando uma aba está ausente — importa as demais e sinaliza a aba" do
    path = build_xlsx(
      cost_center_rows: [cc_row(cr: "CR-OK1", desc: "Contrato A")],
      omit_sheets: [:receipts]
    )

    result = described_class.new(path).call

    expect(result.imported).to eq(1)
    expect(CostCenter.find_by(cr_code: "CR-OK1")).to be_present
    expect(result.errors.any? { |e| e.include?("RECEBIMENTO") }).to be(true)
  end

  it "retorna erro fatal quando o arquivo não pode ser aberto" do
    result = described_class.new("/caminho/inexistente.xlsx").call
    expect(result.success?).to be(false)
    expect(result.fatal_error).to be_present
  end
end
