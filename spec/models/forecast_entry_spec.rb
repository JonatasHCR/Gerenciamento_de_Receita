require 'rails_helper'

RSpec.describe ForecastEntry, type: :model do
  describe "validations" do
    subject { build(:forecast_entry) }
    it { is_expected.to validate_presence_of(:month_year) }
    it { is_expected.to belong_to(:cost_center) }
  end

  describe ".month_year_for" do
    it "converte data para MÊS/ANO em português" do
      expect(described_class.month_year_for(Date.new(2026, 6, 15))).to eq("JUNHO/2026")
      expect(described_class.month_year_for(Date.new(2026, 3, 1))).to eq("MARÇO/2026")
    end
  end

  describe "#period_range" do
    it "converte MÊS/ANO no intervalo do mês" do
      fe = build(:forecast_entry, month_year: "JUNHO/2026")
      expect(fe.period_range).to eq(Date.new(2026, 6, 1)..Date.new(2026, 6, 30))
    end

    it "retorna nil para formato inválido" do
      expect(build(:forecast_entry, month_year: "xxx").period_range).to be_nil
    end
  end

  describe "realized_total derivado do faturamento" do
    let(:cc) { create(:cost_center) }

    it "calcula a partir das NFs existentes na criação" do
      create(:invoice, cost_center: cc, issued_at: Date.new(2026, 6, 10), value: 4_000)
      create(:invoice, cost_center: cc, issued_at: Date.new(2026, 6, 20), value: 1_000)

      fe = create(:forecast_entry, cost_center: cc, month_year: "JUNHO/2026", forecasted_total: 10_000)

      expect(fe.realized_total).to eq(5_000)
      expect(fe.difference).to eq(-5_000) # faltam 5k
    end

    it "ignora NFs de outros meses" do
      create(:invoice, cost_center: cc, issued_at: Date.new(2026, 5, 10), value: 9_999)
      fe = create(:forecast_entry, cost_center: cc, month_year: "JUNHO/2026")
      expect(fe.realized_total).to eq(0)
    end
  end
end
