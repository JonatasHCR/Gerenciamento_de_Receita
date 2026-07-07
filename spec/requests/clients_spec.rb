require 'rails_helper'

RSpec.describe "Clients", type: :request do
  let(:admin)      { create(:user, :admin) }
  let(:financeiro) { create(:user, :financeiro) }
  let(:gestor)     { create(:user, :gestor) }
  let(:coordenador){ create(:user, :coordenador) }
  let(:client)     { create(:client) }

  let(:valid_params)   { { client: { name: "NOVO", full_name: "Novo Órgão Público" } } }
  let(:invalid_params) { { client: { name: "" } } }

  # ── Authentication ────────────────────────────────────────────────────────
  describe "unauthenticated" do
    it "redirects to sign in" do
      get clients_path
      expect(response).to redirect_to new_user_session_path
    end
  end

  # ── GET /clients ──────────────────────────────────────────────────────────
  describe "GET /clients" do
    it "returns 200 for financeiro" do
      sign_in financeiro
      get clients_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for gestor" do
      sign_in gestor
      get clients_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for coordenador" do
      sign_in coordenador
      get clients_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ── GET /clients/:id ──────────────────────────────────────────────────────
  describe "GET /clients/:id" do
    it "returns 200 for any authenticated user" do
      sign_in gestor
      get client_path(client)
      expect(response).to have_http_status(:ok)
    end

    it "não expõe ao coordenador os CCs do cliente que não são dele" do
      meu_cc    = create(:cost_center, client: client, cr_code: "CR-MEU")
      outro_cc  = create(:cost_center, client: client, cr_code: "CR-ALHEIO")
      UserCostCenter.create!(user: coordenador, cost_center: meu_cc)

      sign_in coordenador
      get client_path(client)

      expect(response.body).to include("CR-MEU")
      expect(response.body).not_to include("CR-ALHEIO")
      expect(response.body).not_to include(cost_center_path(outro_cc))
    end
  end

  # ── POST /clients ─────────────────────────────────────────────────────────
  describe "POST /clients" do
    context "as financeiro" do
      before { sign_in financeiro }

      it "creates client and redirects to show" do
        post clients_path, params: valid_params
        expect(response).to redirect_to client_path(Client.last)
        expect(flash[:notice]).to be_present
      end

      it "renders new with 422 on invalid params" do
        post clients_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it "permite gestor criar cliente" do
      sign_in gestor
      post clients_path, params: valid_params
      expect(response).to redirect_to client_path(Client.last)
    end

    it "permite coordenador criar cliente" do
      sign_in coordenador
      post clients_path, params: valid_params
      expect(response).to redirect_to client_path(Client.last)
    end
  end

  # ── PATCH /clients/:id ────────────────────────────────────────────────────
  describe "PATCH /clients/:id" do
    context "as financeiro" do
      before { sign_in financeiro }

      it "updates and redirects" do
        patch client_path(client), params: { client: { full_name: "Nome Atualizado" } }
        expect(response).to redirect_to client_path(client)
        expect(flash[:notice]).to be_present
      end

      it "renders edit with 422 on invalid params" do
        patch client_path(client), params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it "blocks gestor" do
      sign_in gestor
      patch client_path(client), params: { client: { full_name: "X" } }
      expect(response).to redirect_to root_path
    end
  end

  # ── DELETE /clients/:id ───────────────────────────────────────────────────
  describe "DELETE /clients/:id" do
    it "admin can destroy" do
      sign_in admin
      delete client_path(client)
      expect(response).to redirect_to clients_path
      expect(flash[:notice]).to be_present
    end

    it "financeiro cannot destroy" do
      sign_in financeiro
      delete client_path(client)
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to be_present
    end

    it "cannot destroy client with associated cost centers" do
      sign_in admin
      create(:cost_center, client: client)
      delete client_path(client)
      expect(response).to redirect_to client_path(client)
      expect(flash[:alert]).to be_present
    end
  end
end
