require 'rails_helper'

RSpec.describe Invoice, type: :model do
  subject(:invoice) { build(:invoice) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:number) }
    it { is_expected.to validate_presence_of(:client_name) }
    it { is_expected.to validate_presence_of(:issued_at) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_numericality_of(:value).is_greater_than(0) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:cost_center) }
    it { is_expected.to have_many(:receipts).dependent(:destroy) }
  end

  describe "#balance" do
    let(:invoice) { create(:invoice, value: 3000) }

    it "returns full value when no receipts" do
      expect(invoice.balance).to eq(3000)
    end

    it "returns remaining value after partial receipt" do
      create(:receipt, invoice: invoice, value: 1500)
      expect(invoice.balance).to eq(1500)
    end

    it "returns zero after full payment" do
      create(:receipt, invoice: invoice, value: 3000)
      expect(invoice.balance).to eq(0)
    end
  end

  describe "#payment_status" do
    let(:invoice) { create(:invoice, value: 3000) }

    it "returns :unpaid when no receipts" do
      expect(invoice.payment_status).to eq(:unpaid)
    end

    it "returns :partial when partially paid" do
      create(:receipt, invoice: invoice, value: 1500)
      expect(invoice.payment_status).to eq(:partial)
    end

    it "returns :paid when fully paid" do
      create(:receipt, invoice: invoice, value: 3000)
      expect(invoice.payment_status).to eq(:paid)
    end
  end

  describe "sincronização do realizado da previsão" do
    let(:cc) { create(:cost_center) }
    let!(:forecast) do
      create(:forecast_entry, cost_center: cc, month_year: "JUNHO/2026", forecasted_total: 10_000)
    end

    it "atualiza realized ao criar NF no mês" do
      create(:invoice, cost_center: cc, issued_at: Date.new(2026, 6, 10), value: 5_000)
      expect(forecast.reload.realized_total).to eq(5_000)
    end

    it "acumula múltiplas NFs do mês" do
      create(:invoice, cost_center: cc, issued_at: Date.new(2026, 6, 10), value: 5_000)
      create(:invoice, cost_center: cc, issued_at: Date.new(2026, 6, 25), value: 2_000)
      expect(forecast.reload.realized_total).to eq(7_000)
    end

    it "reduz realized ao excluir NF" do
      inv = create(:invoice, cost_center: cc, issued_at: Date.new(2026, 6, 10), value: 5_000)
      expect(forecast.reload.realized_total).to eq(5_000)
      inv.destroy
      expect(forecast.reload.realized_total).to eq(0)
    end

    it "recalcula ao alterar o valor da NF" do
      inv = create(:invoice, cost_center: cc, issued_at: Date.new(2026, 6, 10), value: 5_000)
      inv.update!(value: 8_000)
      expect(forecast.reload.realized_total).to eq(8_000)
    end

    it "move o realizado ao mudar a data da NF para outro mês" do
      may = create(:forecast_entry, cost_center: cc, month_year: "MAIO/2026", forecasted_total: 1)
      inv = create(:invoice, cost_center: cc, issued_at: Date.new(2026, 6, 10), value: 5_000)
      expect(forecast.reload.realized_total).to eq(5_000)

      inv.update!(issued_at: Date.new(2026, 5, 10))
      expect(forecast.reload.realized_total).to eq(0)
      expect(may.reload.realized_total).to eq(5_000)
    end

    it "não afeta NF fora do período da previsão" do
      create(:invoice, cost_center: cc, issued_at: Date.new(2026, 7, 1), value: 9_999)
      expect(forecast.reload.realized_total).to eq(0)
    end
  end
end
