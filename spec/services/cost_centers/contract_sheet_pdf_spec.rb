require 'rails_helper'

RSpec.describe CostCenters::ContractSheetPdf do
  let(:client) { create(:client, name: "Secretaria de Educação") }
  let(:cc) do
    create(:cost_center, client: client, value: 50_000, participation: 0.5,
                         description: "Manutenção Elétrica", object_text: "Serviços de instalação")
  end

  # Captura o conteúdo das tabelas: o texto dentro do PDF sai codificado.
  def rendered_tables(cost_center)
    tables = []
    allow_any_instance_of(Prawn::Document).to receive(:table).and_wrap_original do |m, data, *args, **opts, &blk|
      tables << data
      m.call(data, *args, **opts, &blk)
    end
    pdf = described_class.new(cost_center, generated_by: "Fulano").render
    [pdf, tables.flatten.map(&:to_s)]
  end

  it "gera o PDF com os dados do contrato acentuados" do
    pdf, cells = rendered_tables(cc)
    expect(pdf[0, 4]).to eq("%PDF")
    expect(cells).to include("Secretaria de Educação", "Serviços de instalação", "Participação UFC", "50%")
    expect(cells).to include("Saldo total do contrato")
  end

  it "lista os reajustes sem a observação e sem notas fiscais" do
    create(:adjustment, cost_center: cc, amount: 10_000, note: "observação interna")
    create(:invoice, cost_center: cc, value: 1_000, number: "NF-777")
    _pdf, cells = rendered_tables(cc.reload)
    expect(cells).to include("Valor", "R$ 60.000,00")
    expect(cells.join(" ")).not_to include("observação interna")
    expect(cells.join(" ")).not_to include("NF-777")
  end
end
