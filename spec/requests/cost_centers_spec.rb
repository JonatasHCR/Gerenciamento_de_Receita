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
        cr_code:       "9999",
        description:   "NOVO CONTRATO",
        participation: 1.0,
        coordinator:   "Fulano",
        client_id:     client.id
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

    it "filters by search query" do
      sign_in admin
      get cost_centers_path, params: { q: cost_center.description }
      expect(response).to have_http_status(:ok)
    end
  end

  # ── GET /cost_centers/:id ─────────────────────────────────────────────────
  describe "GET /cost_centers/:id" do
    it "returns 200 for any authenticated role" do
      [admin, financeiro, gestor, coordenador].each do |user|
        sign_in user
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

      it "cannot create a new cost center (not in own_cost_center? for new record)" do
        post cost_centers_path, params: valid_params
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end

      it "can create when linked to the cost center" do
        UserCostCenter.create!(user: coordenador, cost_center: cost_center)
        patch cost_center_path(cost_center), params: { cost_center: { coordinator: "Novo" } }
        expect(response).to redirect_to cost_center_path(cost_center)
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
