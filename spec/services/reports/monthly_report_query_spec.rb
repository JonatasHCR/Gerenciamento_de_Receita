require 'rails_helper'

RSpec.describe Reports::MonthlyReportQuery do
  let(:month)      { Date.new(2026, 6, 1) }
  let(:month_year) { "JUNHO/2026" }

  let(:client_a) { create(:client, name: "AAA Cliente") }
  let(:client_b) { create(:client, name: "BBB Cliente") }
  let(:cc_a)     { create(:cost_center, client: client_a, cr_code: "1001") }
  let(:cc_b)     { create(:cost_center, client: client_b, cr_code: "2001") }

  subject(:result) do
    described_class.new(period_start: month.beginning_of_month,
                        period_end: month.end_of_month, scope: CostCenter.all).call
  end

  # Com levels: [:cliente] (padrão), cada grupo é um cliente e as linhas de CC
  # ficam no próprio nó (nível folha).
  def group_for(res, client) = res[:groups].find { |g| g[:record] == client }
  def rows_for(res, client)  = group_for(res, client)[:rows]
  def row_for(res, client)   = rows_for(res, client).first

  before do
    # Previsão do mês
    create(:forecast_entry, cost_center: cc_a, month_year: month_year, forecasted_total: 50_000)

    # Faturamento no mês (junho) e mês anterior (maio)
    inv_cur = create(:invoice, cost_center: cc_a, issued_at: Date.new(2026, 6, 10), value: 30_000)
    create(:invoice, cost_center: cc_a, issued_at: Date.new(2026, 5, 10), value: 20_000)

    # Recebimento no mês sobre a NF de junho (parcial)
    create(:receipt, invoice: inv_cur, payment_date: Date.new(2026, 6, 20), value: 10_000)

    # Outro cliente só com faturamento no mês
    create(:invoice, cost_center: cc_b, issued_at: Date.new(2026, 6, 5), value: 5_000)
  end

  it "agrupa por cliente em ordem alfabética" do
    mine = result[:groups].map { |g| g[:record] }.select { |c| [client_a, client_b].include?(c) }
    expect(mine).to eq([client_a, client_b])
  end

  it "calcula previsto, faturado no mês e mês anterior" do
    row = row_for(result, client_a)

    expect(row[:previsto]).to eq(50_000)
    expect(row[:inv_cur]).to eq(30_000)
    expect(row[:inv_pre]).to eq(20_000)
    expect(row[:rec_cur]).to eq(10_000)
  end

  it "calcula faturas em aberto até o fim do mês (faturado - recebido)" do
    # 30k + 20k faturados, 10k recebidos => 40k em aberto
    expect(row_for(result, client_a)[:open]).to eq(40_000)
  end

  it "em aberto de meses anteriores = faturamento anterior sem pagamentos prévios" do
    # NF anterior (maio) = 20k, nenhum pagamento até o mês anterior => 20k em aberto ant.
    expect(row_for(result, client_a)[:open_pre]).to eq(20_000)
  end

  it "NÃO desconta pagamentos feitos no mês selecionado do em aberto anterior" do
    inv_may = Invoice.where(cost_center: cc_a, issued_at: Date.new(2026, 5, 10)).first
    create(:receipt, invoice: inv_may, payment_date: Date.new(2026, 6, 5), value: 8_000)

    # Pagamento foi em JUNHO (mês selecionado) → não baixa o aberto anterior => 20k
    expect(row_for(result, client_a)[:open_pre]).to eq(20_000)
  end

  it "desconta apenas pagamentos feitos ATÉ o mês anterior" do
    # NF emitida em abril (5k) paga parcialmente em maio (2k) — ambos antes de junho
    inv_apr = create(:invoice, cost_center: cc_a, issued_at: Date.new(2026, 4, 5), value: 5_000)
    create(:receipt, invoice: inv_apr, payment_date: Date.new(2026, 5, 20), value: 2_000)

    # inv_pre = 20k (maio) + 5k (abril) = 25k; pago até o mês anterior = 2k => 23k
    expect(row_for(result, client_a)[:open_pre]).to eq(23_000)
  end

  it "monta os totais por cliente" do
    totals = group_for(result, client_a)[:totals]
    expect(totals[:inv_cur]).to eq(30_000)
    expect(totals[:open]).to eq(40_000)
  end

  it "monta o total geral sobre as linhas planas" do
    scoped = described_class.new(period_start: month.beginning_of_month, period_end: month.end_of_month,
                                 scope: CostCenter.where(id: [cc_a.id, cc_b.id])).call
    expect(scoped[:totals][:inv_cur]).to eq(35_000)
  end

  it "ignora meses futuros no faturado no mês" do
    create(:invoice, cost_center: cc_a, issued_at: Date.new(2026, 7, 1), value: 99_999)
    expect(row_for(result, client_a)[:inv_cur]).to eq(30_000)
  end

  it "omite o cliente quando TODOS os seus CCs estão zerados" do
    client_c = create(:client, name: "CCC Cliente")
    cc_c     = create(:cost_center, client: client_c, cr_code: "3001")
    create(:forecast_entry, cost_center: cc_c, month_year: month_year, forecasted_total: 0)

    expect(result[:groups].map { |g| g[:record] }).not_to include(client_c)
  end

  it "mantém o cliente e omite só o CC zerado quando há outro com valor" do
    cc_a2 = create(:cost_center, client: client_a, cr_code: "1002")
    create(:forecast_entry, cost_center: cc_a2, month_year: month_year, forecasted_total: 0)

    crs = rows_for(result, client_a).map { |r| r[:cc].cr_code }
    expect(crs).to include("1001")
    expect(crs).not_to include("1002")
  end

  describe "agrupamento por coordenador" do
    subject(:coord_result) do
      described_class.new(period_start: month.beginning_of_month, period_end: month.end_of_month,
                          scope: CostCenter.where(id: [cc_a.id, cc_b.id]),
                          levels: %i[coordenador cliente]).call
    end

    before { cc_a.update!(coordinator: "Bruno / Ana") }

    it "cria um grupo por coordenador, com o cliente abaixo" do
      bruno = coord_result[:groups].find { |g| g[:label] == "Bruno" }
      expect(coord_result[:groups].map { |g| g[:label] }).to include("Ana", "Bruno")
      expect(bruno[:children].map { |c| c[:label] }).to eq(["AAA Cliente"])
      expect(bruno[:children].first[:rows].first[:cc]).to eq(cc_a)
    end

    it "não duplica o CC de 2 coordenadores no total geral" do
      expect(coord_result[:totals][:inv_cur]).to eq(35_000)
    end
  end

  describe "modo período (intervalo de datas)" do
    subject(:period_result) do
      described_class.new(period_start: Date.new(2026, 5, 1),
                          period_end: Date.new(2026, 6, 30), scope: CostCenter.all).call
    end

    before do
      # Previsão de julho não deve entrar no período mai-jun.
      create(:forecast_entry, cost_center: cc_a, month_year: "MAIO/2026", forecasted_total: 40_000)
      create(:forecast_entry, cost_center: cc_a, month_year: "JULHO/2026", forecasted_total: 99_000)
    end

    it "acumula previsto de todos os meses do período (jun 50k + mai 40k)" do
      expect(row_for(period_result, client_a)[:previsto]).to eq(90_000)
    end

    it "acumula faturado no período (mai 20k + jun 30k) e não há anterior" do
      row = row_for(period_result, client_a)
      expect(row[:inv_cur]).to eq(50_000)
      expect(row[:inv_pre]).to eq(0)
    end

    it "em aberto é snapshot no fim do período (50k faturado - 10k recebido)" do
      expect(row_for(period_result, client_a)[:open]).to eq(40_000)
    end
  end
end
