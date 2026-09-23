require 'rails_helper'

RSpec.describe CostCenters::ContractSheetPdf do
  let(:client) { create(:client, name: "Secretaria de Educação") }
  let(:cc) do
    create(:cost_center, client: client, value: 50_000, participation: 0.5,
                         description: "Manutenção Elétrica", object_text: "Serviços de instalação")
  end

  # Captura o texto escrito: dentro do PDF ele sai codificado.
  def rendered(cost_center)
    texts = []
    allow_any_instance_of(Prawn::Document).to receive(:text).and_wrap_original do |m, str, *args, **opts|
      texts << str.to_s
      m.call(str, *args, **opts)
    end
    pdf = described_class.new(cost_center, generated_by: "Fulano").render
    [pdf, texts.join("\n")]
  end

  it "gera o PDF com os dados do contrato acentuados" do
    pdf, text = rendered(cc)
    expect(pdf[0, 4]).to eq("%PDF")
    expect(text).to include("Manutenção Elétrica", "Secretaria de Educação", "Serviços de instalação",
                            "PARTICIPAÇÃO UFC", "50%", "Saldo total do contrato")
  end

  it "lista os reajustes sem a observação e sem notas fiscais" do
    create(:adjustment, cost_center: cc, amount: 10_000, note: "observação interna")
    create(:invoice, cost_center: cc, value: 1_000, number: "NF-777")
    _pdf, text = rendered(cc.reload)
    expect(text).to include("R$ 60.000,00")
    expect(text).not_to include("observação interna")
    expect(text).not_to include("NF-777")
  end
end
