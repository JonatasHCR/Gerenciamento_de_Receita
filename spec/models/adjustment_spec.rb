require "rails_helper"

RSpec.describe Adjustment, type: :model do
  let(:cost_center) { create(:cost_center, value: 50_000, end_date: Date.new(2026, 6, 5)) }

  describe "reajuste de valor" do
    it "captura o valor anterior e aplica o novo ao CC" do
      adj = cost_center.adjustments.create!(kind: :valor, new_value: 60_000)
      expect(adj.previous_value).to eq(50_000)
      expect(cost_center.reload.value).to eq(60_000)
    end

    it "exige novo valor" do
      adj = cost_center.adjustments.build(kind: :valor, new_value: nil)
      expect(adj).not_to be_valid
    end
  end

  describe "reajuste de prazo" do
    it "captura a data anterior e aplica a nova data final ao CC" do
      adj = cost_center.adjustments.create!(kind: :prazo, new_date: Date.new(2027, 6, 5))
      expect(adj.previous_date).to eq(Date.new(2026, 6, 5))
      expect(cost_center.reload.end_date).to eq(Date.new(2027, 6, 5))
    end
  end
end
