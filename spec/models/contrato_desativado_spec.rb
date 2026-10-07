require "rails_helper"

RSpec.describe "Contrato desativado" do
  let(:contrato) { create(:cost_center) }

  def desativar!
    contrato.update!(active: false)
  end

  it "nasce ativo" do
    expect(contrato).to be_active
  end

  it "não aceita NF nova" do
    desativar!
    nf = build(:invoice, cost_center: contrato)
    expect(nf).not_to be_valid
    expect(nf.errors[:base].join).to include("está desativado")
  end

  it "não aceita alterar NF que já existia" do
    nf = create(:invoice, cost_center: contrato)
    desativar!
    expect(nf.reload.update(observations: "mudou")).to be(false)
  end

  it "não aceita recebimento, previsão nem reajuste" do
    nf = create(:invoice, cost_center: contrato, value: 1000)
    desativar!

    expect(build(:receipt, invoice: nf, value: 10, payment_date: nf.issued_at)).not_to be_valid
    expect(build(:forecast_entry, cost_center: contrato)).not_to be_valid
    expect(build(:adjustment, cost_center: contrato.reload)).not_to be_valid
  end

  it "volta a aceitar depois de reativado" do
    desativar!
    contrato.update!(active: true)
    expect(build(:invoice, cost_center: contrato)).to be_valid
  end

  it "continua existindo e aparece fora do combo dos formulários" do
    outro = create(:cost_center)
    desativar!
    expect(CostCenter.selecionaveis).to contain_exactly(outro)
    expect(CostCenter.selecionaveis(contrato.id)).to contain_exactly(outro, contrato)
  end
end
