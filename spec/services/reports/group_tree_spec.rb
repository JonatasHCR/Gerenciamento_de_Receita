require 'rails_helper'

RSpec.describe Reports::GroupTree do
  let(:client_a) { create(:client, name: "AAA Cliente") }
  let(:client_b) { create(:client, name: "BBB Cliente") }
  let(:cc1) { create(:cost_center, client: client_a, cr_code: "GT-1", coordinator: "Bruno") }
  let(:cc2) { create(:cost_center, client: client_b, cr_code: "GT-2", coordinator: "Bruno / Ana") }

  let(:rows) do
    [{ cc: cc1, value: 100 }, { cc: cc2, value: 40 }]
  end

  def build(levels)
    described_class.build(rows, levels: levels, sum_keys: [:value])
  end

  it "modo plano: um nó único sem rótulo" do
    tree = build([])
    expect(tree[:groups].size).to eq(1)
    expect(tree[:groups].first[:label]).to be_nil
    expect(tree[:groups].first[:rows].size).to eq(2)
    expect(tree[:totals]).to eq(value: 140, count: 2)
  end

  it "agrupa por cliente com subtotais" do
    tree = build([:cliente])
    expect(tree[:groups].map { |g| g[:label] }).to eq(["AAA Cliente", "BBB Cliente"])
    expect(tree[:groups].first[:totals][:value]).to eq(100)
  end

  it "agrupa coordenador → cliente → centro de custo" do
    tree = build(%i[coordenador cliente centro_custo])
    bruno = tree[:groups].find { |g| g[:label] == "Bruno" }

    expect(tree[:groups].map { |g| g[:label] }).to eq(["Ana", "Bruno"])
    expect(bruno[:children].map { |c| c[:label] }).to eq(["AAA Cliente", "BBB Cliente"])
    expect(bruno[:children].first[:children].map { |c| c[:label] }).to eq(["GT-1 — #{cc1.description}"])
  end

  it "CC com 2 coordenadores entra no subtotal de cada um, mas o total geral conta uma vez" do
    tree = build(%i[coordenador])
    ana   = tree[:groups].find { |g| g[:label] == "Ana" }
    bruno = tree[:groups].find { |g| g[:label] == "Bruno" }

    expect(ana[:totals][:value]).to eq(40)
    expect(bruno[:totals][:value]).to eq(140)
    expect(ana[:totals][:value] + bruno[:totals][:value]).to eq(180)
    expect(tree[:totals][:value]).to eq(140)
  end

  it "empurra 'Sem Coordenador' para o fim" do
    cc3 = create(:cost_center, client: client_a, cr_code: "GT-3", coordinator: nil)
    tree = described_class.build(rows + [{ cc: cc3, value: 5 }],
                                 levels: [:coordenador], sum_keys: [:value])
    expect(tree[:groups].map { |g| g[:label] }).to eq(["Ana", "Bruno", "Sem Coordenador"])
  end

  it "ordena ignorando acentos" do
    cc_z = create(:cost_center, client: create(:client, name: "Ácido"), cr_code: "GT-9")
    tree = described_class.build([{ cc: cc_z, value: 1 }, { cc: cc1, value: 2 }],
                                 levels: [:cliente], sum_keys: [:value])
    expect(tree[:groups].map { |g| g[:label] }).to eq(["AAA Cliente", "Ácido"])
  end
end
