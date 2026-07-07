require 'rails_helper'

RSpec.describe "CostCenters", type: :request do
  let(:admin)      { create(:user, :admin) }
  let(:financeiro) { create(:user, :financeiro) }
  let(:gestor)     { create(:user, :gestor) }
  let(:coordenador){ create(:user, :coordenador) }
  let(:client)     { create(:client) }
  let(:cost_center){ create(:cost_center, client: client) }

  let(:valid_params) do
    {
      cost_center: {
        cr_code:               "9999",
        description:           "NOVO CONTRATO",
        participation_percent: 100,
        coordinator_list:      ["Fulano", "Beltrano"],
        client_id:             client.id
      }
    }
  end

  let(:invalid_params) { { cost_center: { cr_code: "", description: "" } } }

  # ── Authentication ────────────────────────────────────────────────────────
  describe "unauthenticated" do
    it "GET /cost_centers redirects to sign in" do
      get cost_centers_path
      expect(response).to redirect_to new_user_session_path
    end
  end

  # ── GET /cost_centers ─────────────────────────────────────────────────────
  describe "GET /cost_centers" do
    it "returns 200 for any authenticated role" do
      [admin, financeiro, gestor, coordenador].each do |user|
        sign_in user
        get cost_centers_path
        expect(response).to have_http_status(:ok), "expected 200 for role #{user.role}"
      end
    end

    it "exibe o saldo (valor − faturado principal) sem N+1" do
      cc = create(:cost_center, client: client, value: 100_000)
      create(:invoice, cost_center: cc, value: 40_000, kind: :principal)
      sign_in admin
      get cost_centers_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Saldo")
    end

    it "filters by search query" do
      sign_in admin
      get cost_centers_path, params: { q: cost_center.description }
      expect(response).to have_http_status(:ok)
    end
  end

  # ── GET /cost_centers/report (Excel) ──────────────────────────────────────
  describe "GET /cost_centers/report" do
    it "gera um Excel para admin" do
      sign_in admin
      get report_cost_centers_path
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    end
  end

  # ── POST /cost_centers/:id/adjustments (reajuste) ─────────────────────────
  describe "POST /cost_centers/:id/adjustments" do
    let(:cc) { create(:cost_center, client: client, value: 50_000) }

    it "registra reajuste de valor e aplica ao CC (admin)" do
      sign_in admin
      post cost_center_adjustments_path(cc), params: { adjustment: { kind: "valor", new_value: 60_000 } }
      expect(response).to redirect_to(cost_center_path(cc))
      expect(cc.reload.value).to eq(60_000)
    end

    it "bloqueia coordenador sem vínculo" do
      sign_in coordenador
      post cost_center_adjustments_path(cc), params: { adjustment: { kind: "valor", new_value: 60_000 } }
      expect(response).to redirect_to(root_path)
    end
  end

  # ── GET /cost_centers/:id ─────────────────────────────────────────────────
  describe "GET /cost_centers/:id" do
    it "returns 200 for admin, financeiro e gestor (veem todos)" do
      [admin, financeiro, gestor].each do |user|
        sign_in user
        get cost_center_path(cost_center)
        expect(response).to have_http_status(:ok), "esperava 200 para #{user.role}"
      end
    end

    context "coordenador" do
      it "é bloqueado em CC que não é dele" do
        sign_in coordenador
        get cost_center_path(cost_center)
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end

      it "vê o CC quando é o coordenador vinculado" do
        UserCostCenter.create!(user: coordenador, cost_center: cost_center)
        sign_in coordenador
        get cost_center_path(cost_center)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ── POST /cost_centers ────────────────────────────────────────────────────
  describe "POST /cost_centers" do
    it "admin creates and redirects" do
      sign_in admin
      post cost_centers_path, params: valid_params
      expect(response).to redirect_to cost_center_path(CostCenter.last)
    end

    it "financeiro can create" do
      sign_in financeiro
      post cost_centers_path, params: valid_params
      expect(response).to redirect_to cost_center_path(CostCenter.last)
    end

    it "gestor can create" do
      sign_in gestor
      post cost_centers_path, params: valid_params
      expect(response).to redirect_to cost_center_path(CostCenter.last)
    end

    it "renders new with 422 on invalid params" do
      sign_in admin
      post cost_centers_path, params: invalid_params
      expect(response).to have_http_status(:unprocessable_entity)
    end

    context "coordenador" do
      before { sign_in coordenador }

      it "cria um CC já vinculado a si mesmo" do
        post cost_centers_path, params: valid_params
        cc = CostCenter.last
        expect(response).to redirect_to cost_center_path(cc)
        expect(cc.coordinator_list).to eq([coordenador.name])
        expect(cc.users).to include(coordenador)
      end
    end
  end

  # ── PATCH /cost_centers/:id ───────────────────────────────────────────────
  describe "PATCH /cost_centers/:id" do
    it "admin updates and redirects" do
      sign_in admin
      patch cost_center_path(cost_center), params: { cost_center: { coordinator: "Novo Coord" } }
      expect(response).to redirect_to cost_center_path(cost_center)
    end

    it "coordenador without link is blocked" do
      sign_in coordenador
      patch cost_center_path(cost_center), params: { cost_center: { coordinator: "X" } }
      expect(response).to redirect_to root_path
    end
  end

  # ── DELETE /cost_centers/:id ──────────────────────────────────────────────
  describe "DELETE /cost_centers/:id" do
    it "admin can destroy" do
      sign_in admin
      delete cost_center_path(cost_center)
      expect(response).to redirect_to cost_centers_path
    end

    it "financeiro cannot destroy" do
      sign_in financeiro
      delete cost_center_path(cost_center)
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to be_present
    end

    it "gestor cannot destroy" do
      sign_in gestor
      delete cost_center_path(cost_center)
      expect(response).to redirect_to root_path
    end

    it "redirects with alert when cost center has invoices" do
      sign_in admin
      create(:invoice, cost_center: cost_center)
      delete cost_center_path(cost_center)
      expect(response).to redirect_to cost_center_path(cost_center)
      expect(flash[:alert]).to be_present
    end
  end
end
