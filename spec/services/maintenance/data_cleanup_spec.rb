require "rails_helper"

# Cobre os alvos/filtros do DataCleanup não exercitados pelo request spec
# (recebimentos, centros, tudo e o filtro por cliente).
RSpec.describe Maintenance::DataCleanup do
  let(:user) { create(:user, :admin) }

  it "apaga só recebimentos (NF permanece), filtrando por CC" do
    cc  = create(:cost_center)
    inv = create(:invoice, cost_center: cc)
    create(:receipt, invoice: inv)

    expect {
      described_class.new(target: "recebimentos", user: user, cost_center_id: cc.id).call
    }.to change(Receipt, :count).by(-1)
    expect(Invoice.exists?(inv.id)).to be(true)
  end

  it "apaga o centro de custo e tudo vinculado" do
    cc  = create(:cost_center)
    inv = create(:invoice, cost_center: cc)
    create(:receipt, invoice: inv)
    create(:forecast_entry, cost_center: cc)

    described_class.new(target: "centros", user: user).call

    expect(CostCenter.exists?(cc.id)).to be(false)
    expect(Invoice.exists?(inv.id)).to be(false)
    expect(ForecastEntry.where(cost_center_id: cc.id)).to be_empty
  end

  it "filtra centros por cliente (não toca nos demais)" do
    c1, c2 = create(:client), create(:client)
    cc1 = create(:cost_center, client: c1)
    cc2 = create(:cost_center, client: c2)

    described_class.new(target: "centros", user: user, client_id: c1.id).call

    expect(CostCenter.exists?(cc1.id)).to be(false)
    expect(CostCenter.exists?(cc2.id)).to be(true)
  end

  it "tudo apaga os dados de negócio mas preserva os usuários" do
    create(:invoice)
    create(:client)

    described_class.new(target: "tudo", user: user).call

    expect(Invoice.count).to eq(0)
    expect(CostCenter.count).to eq(0)
    expect(Client.count).to eq(0)
    expect(User.exists?(user.id)).to be(true)
  end

  it "registra a limpeza na auditoria" do
    create(:forecast_entry)
    expect {
      described_class.new(target: "previsao", user: user).call
    }.to change { PaperTrail::Version.where(item_type: "Manutenção", event: "limpeza").count }.by(1)
  end

  it "rejeita alvo inválido" do
    expect {
      described_class.new(target: "xpto", user: user).call
    }.to raise_error(described_class::InvalidTarget)
  end
end
