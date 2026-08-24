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

  describe "edição do histórico" do
    it "aplica a diferença ao contrato e reencadeia os posteriores" do
      first  = cost_center.adjustments.create!(kind: :valor, amount: 5_000)
      second = cost_center.adjustments.create!(kind: :valor, amount: 2_500)

      first.update!(amount: 1_000)

      expect(first.reload.new_value).to eq(51_000)
      expect(second.reload.previous_value).to eq(51_000)
      expect(second.new_value).to eq(53_500)
      expect(cost_center.reload.value).to eq(53_500)
    end

    it "reverte o valor ao excluir e reencadeia os posteriores" do
      first  = cost_center.adjustments.create!(kind: :valor, amount: 5_000)
      second = cost_center.adjustments.create!(kind: :valor, amount: 2_500)

      first.destroy

      expect(second.reload.previous_value).to eq(50_000)
      expect(second.new_value).to eq(52_500)
      expect(cost_center.reload.value).to eq(52_500)
    end

    it "restaura a data final ao excluir o reajuste de prazo" do
      adj = cost_center.adjustments.create!(kind: :prazo, new_date: Date.new(2027, 6, 5))
      adj.destroy
      expect(cost_center.reload.end_date).to eq(Date.new(2026, 6, 5))
    end

    it "volta para o prazo anterior ao excluir o último de vários" do
      cost_center.adjustments.create!(kind: :prazo, new_date: Date.new(2027, 6, 5))
      last = cost_center.adjustments.create!(kind: :prazo, new_date: Date.new(2028, 6, 5))

      last.destroy

      expect(cost_center.reload.end_date).to eq(Date.new(2027, 6, 5))
    end

    it "aplica a nova data ao editar o reajuste de prazo" do
      adj = cost_center.adjustments.create!(kind: :prazo, new_date: Date.new(2027, 6, 5))
      adj.update!(new_date: Date.new(2029, 1, 31))
      expect(cost_center.reload.end_date).to eq(Date.new(2029, 1, 31))
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
