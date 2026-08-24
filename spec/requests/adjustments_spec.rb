require "rails_helper"

RSpec.describe "Adjustments", type: :request do
  let(:admin)        { create(:user, :admin) }
  let(:financeiro)   { create(:user, :financeiro) }
  let(:gestor)       { create(:user, :gestor) }
  let(:coordenador)  { create(:user, :coordenador) }
  let(:cost_center)  { create(:cost_center, value: 50_000, end_date: Date.new(2026, 6, 5)) }
  let!(:adjustment)  { cost_center.adjustments.create!(kind: :valor, amount: 10_000) }

  describe "GET /adjustments/:id/edit" do
    it "abre para admin e financeiro" do
      [admin, financeiro].each do |user|
        sign_in user
        get edit_adjustment_path(adjustment)
        expect(response).to have_http_status(:ok), "esperava 200 para #{user.role}"
      end
    end

    it "bloqueia gestor e coordenador" do
      [gestor, coordenador].each do |user|
        sign_in user
        get edit_adjustment_path(adjustment)
        expect(response).to redirect_to(root_path), "esperava bloqueio para #{user.role}"
      end
    end
  end

  describe "PATCH /adjustments/:id" do
    it "financeiro altera o valor do reajuste e o contrato acompanha" do
      sign_in financeiro
      patch adjustment_path(adjustment), params: { adjustment: { amount: "4000.00", note: "corrigido" } }
      expect(response).to redirect_to(cost_center_path(cost_center))
      expect(adjustment.reload.new_value).to eq(54_000)
      expect(adjustment.note).to eq("corrigido")
      expect(cost_center.reload.value).to eq(54_000)
    end

    it "bloqueia gestor" do
      sign_in gestor
      patch adjustment_path(adjustment), params: { adjustment: { amount: "4000.00" } }
      expect(response).to redirect_to(root_path)
      expect(cost_center.reload.value).to eq(60_000)
    end
  end

  describe "DELETE /adjustments/:id" do
    it "admin exclui e o contrato volta ao valor anterior" do
      sign_in admin
      delete adjustment_path(adjustment)
      expect(response).to redirect_to(cost_center_path(cost_center))
      expect(Adjustment.exists?(adjustment.id)).to be(false)
      expect(cost_center.reload.value).to eq(50_000)
    end

    it "bloqueia coordenador" do
      sign_in coordenador
      delete adjustment_path(adjustment)
      expect(response).to redirect_to(root_path)
      expect(Adjustment.exists?(adjustment.id)).to be(true)
      expect(cost_center.reload.value).to eq(60_000)
    end
  end

  describe "auditoria" do
    def versions_for(item_type, event)
      PaperTrail::Version.where(item_type: item_type, event: event)
    end

    it "registra quem editou o reajuste e a alteração no contrato" do
      sign_in financeiro
      patch adjustment_path(adjustment), params: { adjustment: { amount: "4000.00" } }

      adj_version = versions_for("Adjustment", "update").where(item_id: adjustment.id).last
      expect(adj_version.whodunnit).to eq(financeiro.id.to_s)
      expect(adj_version.object_changes["new_value"]).to eq([ "60000.0", "54000.0" ])

      cc_version = versions_for("CostCenter", "update").where(item_id: cost_center.id).last
      expect(cc_version.whodunnit).to eq(financeiro.id.to_s)
      expect(cc_version.object_changes["value"]).to eq([ "60000.0", "54000.0" ])
    end

    it "registra quem excluiu o reajuste e a reversão do contrato" do
      sign_in admin
      delete adjustment_path(adjustment)

      adj_version = versions_for("Adjustment", "destroy").where(item_id: adjustment.id).last
      expect(adj_version.whodunnit).to eq(admin.id.to_s)

      cc_version = versions_for("CostCenter", "update").where(item_id: cost_center.id).last
      expect(cc_version.whodunnit).to eq(admin.id.to_s)
      expect(cc_version.object_changes["value"]).to eq([ "60000.0", "50000.0" ])
    end
  end
end
