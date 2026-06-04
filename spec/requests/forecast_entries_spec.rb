require 'rails_helper'

RSpec.describe "ForecastEntries", type: :request do
  let(:admin)      { create(:user, :admin) }
  let(:financeiro) { create(:user, :financeiro) }
  let(:gestor)     { create(:user, :gestor) }
  let(:coordenador){ create(:user, :coordenador) }
  let(:cost_center){ create(:cost_center) }
  let(:entry)      { create(:forecast_entry, cost_center: cost_center) }

  let(:valid_params) do
    {
      forecast_entry: {
        month_year:          "JUNHO/2026",
        forecasted_total:    100_000,
        forecasted_pct_ufc:  100_000,
        realized_total:      0,
        realized_pct_ufc:    0,
        cost_center_id:      cost_center.id
      }
    }
  end

  let(:invalid_params) { { forecast_entry: { month_year: "", cost_center_id: nil } } }

  # ── Authentication ────────────────────────────────────────────────────────
  describe "unauthenticated" do
    it "GET /forecast_entries redirects to sign in" do
      get forecast_entries_path
      expect(response).to redirect_to new_user_session_path
    end
  end

  # ── GET /forecast_entries ─────────────────────────────────────────────────
  describe "GET /forecast_entries" do
    it "returns 200 for any authenticated role" do
      [admin, financeiro, gestor, coordenador].each do |user|
        sign_in user
        get forecast_entries_path
        expect(response).to have_http_status(:ok), "expected 200 for role #{user.role}"
      end
    end

    it "accepts month_year filter" do
      sign_in admin
      get forecast_entries_path, params: { month_year: "JUNHO/2026" }
      expect(response).to have_http_status(:ok)
    end
  end

  # ── POST /forecast_entries ────────────────────────────────────────────────
  describe "POST /forecast_entries" do
    it "admin creates and redirects" do
      sign_in admin
      post forecast_entries_path, params: valid_params
      expect(response).to redirect_to forecast_entries_path
    end

    it "financeiro can create" do
      sign_in financeiro
      post forecast_entries_path, params: valid_params
      expect(response).to redirect_to forecast_entries_path
    end

    it "gestor can create" do
      sign_in gestor
      post forecast_entries_path, params: valid_params
      expect(response).to redirect_to forecast_entries_path
    end

    it "renders new with 422 on invalid params" do
      sign_in admin
      post forecast_entries_path, params: invalid_params
      expect(response).to have_http_status(:unprocessable_entity)
    end

    context "coordenador" do
      before { sign_in coordenador }

      it "cannot create without link to cost center" do
        post forecast_entries_path, params: valid_params
        expect(response).to redirect_to root_path
        expect(flash[:alert]).to be_present
      end

      it "can create when linked to the cost center" do
        UserCostCenter.create!(user: coordenador, cost_center: cost_center)
        post forecast_entries_path, params: valid_params
        expect(response).to redirect_to forecast_entries_path
      end
    end
  end

  # ── PATCH /forecast_entries/:id ───────────────────────────────────────────
  describe "PATCH /forecast_entries/:id" do
    context "as gestor" do
      before { sign_in gestor }

      it "updates and redirects" do
        patch forecast_entry_path(entry), params: { forecast_entry: { realized_total: 50_000 } }
        expect(response).to redirect_to forecast_entries_path
      end
    end

    context "as coordenador" do
      before { sign_in coordenador }

      it "blocked without ownership" do
        patch forecast_entry_path(entry), params: { forecast_entry: { realized_total: 50_000 } }
        expect(response).to redirect_to root_path
      end

      it "allowed with ownership" do
        UserCostCenter.create!(user: coordenador, cost_center: cost_center)
        patch forecast_entry_path(entry), params: { forecast_entry: { realized_total: 50_000 } }
        expect(response).to redirect_to forecast_entries_path
      end
    end
  end

  # ── DELETE /forecast_entries/:id ──────────────────────────────────────────
  describe "DELETE /forecast_entries/:id" do
    it "admin can destroy" do
      sign_in admin
      delete forecast_entry_path(entry)
      expect(response).to redirect_to forecast_entries_path
    end

    it "gestor can destroy" do
      sign_in gestor
      delete forecast_entry_path(entry)
      expect(response).to redirect_to forecast_entries_path
    end

    it "coordenador cannot destroy" do
      sign_in coordenador
      delete forecast_entry_path(entry)
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to be_present
    end
  end
end
