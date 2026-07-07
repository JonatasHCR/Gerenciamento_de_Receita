require "rails_helper"

RSpec.describe Reports::OpenInvoicesReportQuery do
  let(:client) { create(:client, name: "ZZZ Cliente Teste") }
  let(:cc1)    { create(:cost_center, client: client, cr_code: "OI-1", contract_number: "024/2022") }
  let(:cc2)    { create(:cost_center, client: client, cr_code: "OI-2", contract_number: "133/2022") }

  def group_for(result, cli) = result.find { |g| g[:client] == cli }

  it "agrupa por cliente → CC e usa VALOR = saldo em aberto" do
    inv1 = create(:invoice, cost_center: cc1, value: 100_000)
    create(:receipt, invoice: inv1, value: 40_000)         # saldo 60.000
    create(:invoice, cost_center: cc2, value: 30_000)      # saldo 30.000

    result = described_class.new(client_ids: [client.id]).call
    group  = group_for(result, client)

    expect(group[:cost_centers].map { |c| c[:cc] }).to contain_exactly(cc1, cc2)
    oi1 = group[:cost_centers].find { |c| c[:cc] == cc1 }
    expect(oi1[:invoices].first.balance).to eq(60_000)
    expect(oi1[:subtotal]).to eq(60_000)
    expect(group[:total]).to eq(90_000)
  end

  it "omite NF quitada (saldo zero)" do
    quitada = create(:invoice, cost_center: cc1, value: 50_000)
    create(:receipt, invoice: quitada, value: 50_000)
    create(:invoice, cost_center: cc2, value: 20_000)

    group = group_for(described_class.new(client_ids: [client.id]).call, client)
    numbers = group[:cost_centers].flat_map { |c| c[:invoices].map(&:number) }
    expect(numbers).not_to include(quitada.number)
    expect(group[:total]).to eq(20_000)
  end

  it "filtra por client_ids" do
    outro = create(:client, name: "YYY Outro")
    outro_cc = create(:cost_center, client: outro, cr_code: "OI-9")
    create(:invoice, cost_center: cc1, value: 10_000)
    create(:invoice, cost_center: outro_cc, value: 99_000)

    result = described_class.new(client_ids: [client.id]).call
    expect(result.map { |g| g[:client] }).to include(client)
    expect(result.map { |g| g[:client] }).not_to include(outro)
  end
end
