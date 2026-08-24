require "rails_helper"

RSpec.describe Adjustment, type: :model do
  let(:cost_center) { create(:cost_center, value: 50_000, end_date: Date.new(2026, 6, 5)) }

  describe "reajuste de valor" do
    it "soma o valor do reajuste ao valor do contrato" do
      adj = cost_center.adjustments.create!(kind: :valor, amount: 5_000)
      expect(adj.previous_value).to eq(50_000)
      expect(adj.new_value).to eq(55_000)
      expect(adj.value_delta).to eq(5_000)
      expect(cost_center.reload.value).to eq(55_000)
    end

    it "acumula reajustes sucessivos" do
      cost_center.adjustments.create!(kind: :valor, amount: 5_000)
      cost_center.adjustments.create!(kind: :valor, amount: "2500.00")
      expect(cost_center.reload.value).to eq(57_500)
    end

    it "captura o valor anterior e aplica o novo ao CC" do
      adj = cost_center.adjustments.create!(kind: :valor, new_value: 60_000)
      expect(adj.previous_value).to eq(50_000)
      expect(cost_center.reload.value).to eq(60_000)
    end

    it "exige novo valor" do
      adj = cost_center.adjustments.build(kind: :valor, new_value: nil)
      expect(adj).not_to be_valid
    end

    it "não aceita reajuste zerado ou negativo" do
      expect(cost_center.adjustments.build(kind: :valor, amount: 0)).not_to be_valid
      expect(cost_center.adjustments.build(kind: :valor, amount: -100)).not_to be_valid
    end
  end

  describe "reajuste de prazo" do
    it "captura a data anterior e aplica a nova data final ao CC" do
      adj = cost_center.adjustments.create!(kind: :prazo, new_date: Date.new(2027, 6, 5))
      expect(adj.previous_date).to eq(Date.new(2026, 6, 5))
      expect(cost_center.reload.end_date).to eq(Date.new(2027, 6, 5))
    end

    it "não aceita nova data final anterior ao início do contrato" do
      cost_center.update!(start_date: Date.new(2026, 1, 1))
      adj = cost_center.adjustments.build(kind: :prazo, new_date: Date.new(2025, 1, 1))
      expect(adj).not_to be_valid
    end
  end
end
