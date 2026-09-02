require 'rails_helper'

RSpec.describe Reports::MovementReportQuery do
  let(:client) { create(:client, name: "MOV Cliente") }
  let(:cc)     { create(:cost_center, client: client, cr_code: "MOV-1", coordinator: "Bruno") }

  # NF de maio quitada, NF de junho parcialmente paga, NF de julho intocada.
  let!(:inv_may) { create(:invoice, cost_center: cc, number: "100", issued_at: Date.new(2026, 5, 10), value: 20_000) }
  let!(:inv_jun) { create(:invoice, cost_center: cc, number: "200", issued_at: Date.new(2026, 6, 10), value: 30_000) }
  let!(:inv_jul) { create(:invoice, cost_center: cc, number: "300", issued_at: Date.new(2026, 7, 10), value: 5_000) }

  let!(:rec_may) { create(:receipt, invoice: inv_may, payment_date: Date.new(2026, 5, 20), value: 20_000) }
  let!(:rec_jun) { create(:receipt, invoice: inv_jun, payment_date: Date.new(2026, 6, 25), value: 10_000) }

  def filter(params = {})
    Reports::ScopeFilter.from_params(ActionController::Parameters.new(params).permit!,
                                     scope: CostCenter.where(id: cc.id))
  end

  def run(**opts)
    described_class.new(filter: filter(opts.delete(:params) || {}), **opts).call
  end

  def section(result, kind)
    result[:sections].find { |s| s[:kind] == kind }
  end

  it "tipo ambos devolve as duas seções" do
    result = run(tipo: :ambos)
    expect(result[:sections].map { |s| s[:kind] }).to eq(%i[faturamento recebimento])
  end

  it "tipo faturamento lista as NFs por data de emissão com saldo e destaque" do
    result = run(tipo: :faturamento)
    rows = section(result, :faturamento)[:tree][:groups].flat_map { |g| g[:children].flat_map { |c| c[:rows] } }

    expect(rows.map { |r| r[:number] }).to eq(%w[100 200 300])
    expect(rows.map { |r| r[:balance] }).to eq([0, 20_000, 5_000])
    expect(rows.map { |r| r[:partial] }).to eq([false, true, false])
    expect(rows.map { |r| r[:open] }).to eq([false, true, true])
  end

  it "tipo recebimento lista as baixas por data de pagamento" do
    result = run(tipo: :recebimento)
    expect(section(result, :faturamento)).to be_nil
    rows = section(result, :recebimento)[:tree][:groups].flat_map { |g| g[:children].flat_map { |c| c[:rows] } }
    expect(rows.map { |r| r[:payment_date] }).to eq([rec_may.payment_date, rec_jun.payment_date])
  end

  it "monta as colunas conforme o tipo" do
    # Faturamento sozinho: só a relação de faturamento, sem em aberto.
    expect(section(run(tipo: :faturamento), :faturamento)[:columns])
      .to eq(%i[number issued_at cr_code contract_number value])

    # Recebimento: sem data de emissão.
    expect(section(run(tipo: :recebimento), :recebimento)[:columns])
      .to eq(%i[number payment_date cr_code contract_number value])

    # Juntos: ganha a DT BAIXA e o VALOR passa a ser o recebido.
    ambos = section(run(tipo: :ambos), :faturamento)
    expect(ambos[:columns]).to eq(%i[number issued_at last_payment cr_code contract_number received])
    expect(ambos[:headers][:received]).to eq("VALOR")
  end

  it "consolida os totais conforme o tipo" do
    faturamento = section(run(tipo: :faturamento), :faturamento)
    expect(faturamento[:total_columns]).to eq(%i[value])
    expect(faturamento[:leaf_total_keys]).to eq(%i[value])

    ambos = section(run(tipo: :ambos), :faturamento)
    expect(ambos[:total_columns]).to eq(%i[value received balance])
    expect(ambos[:leaf_total_keys]).to eq(%i[value balance])
  end

  it "rotula os totais do recebimento como recebido, não como faturado" do
    recebimento = section(run(tipo: :recebimento), :recebimento)

    expect(recebimento[:total_columns]).to eq(%i[value])
    expect(recebimento[:total_labels][:value]).to eq("Recebido")
    expect(recebimento[:leaf_labels][:value]).to eq("Total recebido")
  end

  describe "somente faturas em aberto" do
    subject(:aberto) { section(run(tipo: :faturamento, only_open: true), :faturamento) }

    it "troca o valor faturado pelo em aberto" do
      expect(aberto[:columns]).to eq(%i[number issued_at cr_code contract_number balance])
      expect(aberto[:total_columns]).to eq(%i[balance])
      expect(aberto[:leaf_total_keys]).to eq(%i[balance])
    end

    it "sinaliza só os recebimentos parciais" do
      expect(aberto[:blocks].first[:flags]).to eq(%i[partial])
      expect(aberto[:blocks].first[:amount]).to eq(:balance)
    end
  end

  describe "blocos do faturamento" do
    def blocks(tipo) = section(run(tipo: tipo), :faturamento)[:blocks]

    it "no tipo faturamento é um bloco só, com o valor faturado" do
      expect(blocks(:faturamento).map { |b| b.values_at(:key, :scope, :amount) })
        .to eq([[:faturado, :all, :value]])
    end

    it "no tipo ambos separa o recebido (com total) do que falta receber" do
      expect(blocks(:ambos).map { |b| b.values_at(:key, :scope, :amount, :total_keys) })
        .to eq([[:recebido, :received, :received, %i[received]],
                [:em_aberto, :open, :balance, []]])
    end

    it "não sinaliza nada na relação simples de faturamento" do
      expect(blocks(:faturamento).first[:flags]).to eq([])
    end

    it "no bloco de em aberto marca só as parciais e zera a DT BAIXA" do
      em_aberto = blocks(:ambos).last

      # O valor ali é o que AINDA NÃO foi recebido, então não há data de baixa.
      expect(em_aberto[:flags]).to eq(%i[partial])
      expect(em_aberto[:blank_columns]).to eq(%i[last_payment])
    end
  end

  it "mantém faturado, recebido e saldo em cada linha para os totais" do
    rows = section(run(tipo: :faturamento), :faturamento)[:tree][:groups]
             .flat_map { |g| g[:children].flat_map { |c| c[:rows] } }
             .index_by { |r| r[:number] }

    expect(rows["200"].values_at(:value, :received, :balance)).to eq([30_000, 10_000, 20_000])
    expect(rows["300"].values_at(:value, :received, :balance)).to eq([5_000, 0, 5_000])
  end

  describe "snapshot na data de corte" do
    # A NF de maio foi quitada em 20/05.
    it "conta como NÃO recebida quando a baixa é posterior ao fim do período" do
      row = section(run(tipo: :faturamento, period_end: Date.new(2026, 5, 19)), :faturamento)[:tree][:groups]
              .flat_map { |g| g[:children].flat_map { |c| c[:rows] } }
              .find { |r| r[:number] == "100" }

      expect(row[:received]).to eq(0)
      expect(row[:balance]).to eq(20_000)
      expect(row[:last_payment]).to be_nil
      expect(row[:open]).to be(true)
    end

    it "conta como recebida quando a baixa cabe no período" do
      row = section(run(tipo: :faturamento, period_end: Date.new(2026, 5, 31)), :faturamento)[:tree][:groups]
              .flat_map { |g| g[:children].flat_map { |c| c[:rows] } }
              .find { |r| r[:number] == "100" }

      expect(row[:received]).to eq(20_000)
      expect(row[:balance]).to eq(0)
      expect(row[:open]).to be(false)
    end
  end

  it "traz a data do ÚLTIMO recebimento, em branco quando não houve baixa" do
    create(:receipt, invoice: inv_jun, payment_date: Date.new(2026, 7, 5), value: 5_000)

    rows = section(run(tipo: :ambos), :faturamento)[:tree][:groups]
             .flat_map { |g| g[:children].flat_map { |c| c[:rows] } }
             .index_by { |r| r[:number] }

    expect(rows["100"][:last_payment]).to eq(Date.new(2026, 5, 20))
    expect(rows["200"][:last_payment]).to eq(Date.new(2026, 7, 5))   # a mais recente das duas baixas
    expect(rows["300"][:last_payment]).to be_nil                     # nenhuma baixa
  end

  it "na NF parcial, recebido é a baixa e o restante vai para em aberto" do
    row = section(run(tipo: :ambos), :faturamento)[:tree][:groups]
            .flat_map { |g| g[:children].flat_map { |c| c[:rows] } }
            .find { |r| r[:number] == "200" }

    expect(row[:value]).to eq(30_000)
    expect(row[:received]).to eq(10_000)
    expect(row[:balance]).to eq(20_000)
    expect(row[:partial]).to be(true)
  end

  it "totaliza faturado, em aberto e recebido" do
    s = run(tipo: :ambos)[:summary]
    expect(s[:faturado]).to eq(55_000)
    expect(s[:em_aberto]).to eq(25_000)         # 20k (jun) + 5k (jul)
    expect(s[:recebido]).to eq(30_000)          # baixas do período
    expect(s[:recebido_nas_nfs]).to eq(30_000)  # recebido das NFs listadas
  end

  it "recorta faturamento por emissão e recebimento por baixa, de forma independente" do
    result = run(tipo: :ambos, period_start: Date.new(2026, 6, 1), period_end: Date.new(2026, 6, 30))

    expect(section(result, :faturamento)[:tree][:totals][:value]).to eq(30_000)
    expect(section(result, :recebimento)[:tree][:totals][:value]).to eq(10_000)
  end

  it "sem período traz tudo" do
    expect(run(tipo: :faturamento)[:sections].first[:tree][:totals][:count]).to eq(3)
  end

  it "only_open reproduz a relação de faturas em aberto (some a NF quitada)" do
    result = run(tipo: :faturamento, only_open: true)
    numbers = result[:sections].first[:tree][:groups]
                               .flat_map { |g| g[:children].flat_map { |c| c[:rows] } }
                               .map { |r| r[:number] }
    expect(numbers).to eq(%w[200 300])
  end

  it "agrupa por coordenador quando o filtro pede" do
    result = described_class.new(filter: filter(group_by: "coordenador"), tipo: :faturamento).call
    grupo = result[:sections].first[:tree][:groups].first

    expect(result[:levels]).to eq(%i[coordenador cliente centro_custo])
    expect(grupo[:label]).to eq("Bruno")
    expect(grupo[:children].first[:label]).to eq("MOV Cliente")
  end

  it "respeita a seleção de centros de custo do filtro" do
    other = create(:cost_center, cr_code: "MOV-2")
    create(:invoice, cost_center: other, value: 1_000)

    f = Reports::ScopeFilter.from_params(
      ActionController::Parameters.new(cost_center_ids: [cc.id]).permit!, scope: CostCenter.all
    )
    result = described_class.new(filter: f, tipo: :faturamento).call
    expect(result[:summary][:faturado]).to eq(55_000)
  end
end
