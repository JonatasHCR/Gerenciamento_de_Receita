require 'rails_helper'

RSpec.describe "Invoices", type: :request do
  let(:admin)      { create(:user, :admin) }
  let(:financeiro) { create(:user, :financeiro) }
  let(:gestor)     { create(:user, :gestor) }
  let(:coordenador){ create(:user, :coordenador) }
  let(:cost_center){ create(:cost_center) }
  let(:invoice)    { create(:invoice, cost_center: cost_center) }

  let(:valid_params) do
    {
      invoice: {
        number:        "NF-001",
        client_name:   "CERB",
        issued_at:     Date.current,
        value:         10_000,
        cost_center_id: cost_center.id
      }
    }
  end

  let(:invalid_params) { { invoice: { number: "", value: -1 } } }

  # ── Authentication ────────────────────────────────────────────────────────
  describe "unauthenticated" do
    it "GET /invoices redirects to sign in" do
      get invoices_path
      expect(response).to redirect_to new_user_session_path
    end

    it "POST /invoices redirects to sign in" do
      post invoices_path, params: valid_params
      expect(response).to redirect_to new_user_session_path
    end
  end

  # ── GET /invoices ─────────────────────────────────────────────────────────
  describe "GET /invoices" do
    it "returns 200 for financeiro" do
      sign_in financeiro
      get invoices_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for admin" do
      sign_in admin
      get invoices_path
      expect(response).to have_http_status(:ok)
    end

    it "blocks gestor" do
      sign_in gestor
      get invoices_path
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to be_present
    end

    it "blocks coordenador" do
      sign_in coordenador
      get invoices_path
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to be_present
    end

    it "filtra por número da NF (busca dinâmica)" do
      match = create(:invoice, cost_center: cost_center, number: "NF-BUSCA-123")
      other = create(:invoice, cost_center: cost_center, number: "OUTRA-999")
      sign_in financeiro
      get invoices_path(q: "BUSCA")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("NF-BUSCA-123")
      expect(response.body).not_to include("OUTRA-999")
    end

    context "filtro de situação (quitadas × em aberto)" do
      let!(:aberta)  { create(:invoice, cost_center: cost_center, number: "ABERTA-1", value: 2_000) }
      let!(:quitada) do
        inv = create(:invoice, cost_center: cost_center, number: "QUITADA-1", value: 1_000)
        create(:receipt, invoice: inv, value: 1_000, payment_date: inv.issued_at)
        inv
      end
      before { sign_in financeiro }

      it "por padrão esconde notas quitadas (mostra só em aberto)" do
        get invoices_path
        expect(response.body).to include("ABERTA-1")
        expect(response.body).not_to include("QUITADA-1")
      end

      it "status=paid mostra só quitadas" do
        get invoices_path(status: "paid")
        expect(response.body).to include("QUITADA-1")
        expect(response.body).not_to include("ABERTA-1")
      end

      it "status=all mostra todas" do
        get invoices_path(status: "all")
        expect(response.body).to include("ABERTA-1")
        expect(response.body).to include("QUITADA-1")
      end
    end
  end

  # ── GET /invoices/:id ─────────────────────────────────────────────────────
  describe "GET /invoices/:id" do
    it "returns 200 for financeiro" do
      sign_in financeiro
      get invoice_path(invoice)
      expect(response).to have_http_status(:ok)
    end

    it "blocks gestor" do
      sign_in gestor
      get invoice_path(invoice)
      expect(response).to redirect_to root_path
    end
  end

  # ── POST /invoices ────────────────────────────────────────────────────────
  describe "POST /invoices" do
    context "as financeiro" do
      before { sign_in financeiro }

      it "creates invoice and redirects" do
        post invoices_path, params: valid_params
        expect(response).to redirect_to invoice_path(Invoice.last)
        expect(flash[:notice]).to be_present
      end

      it "renders new with 422 on invalid params" do
        post invoices_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it "blocks gestor" do
      sign_in gestor
      post invoices_path, params: valid_params
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to be_present
    end
  end

  # ── PATCH /invoices/:id ───────────────────────────────────────────────────
  describe "PATCH /invoices/:id" do
    context "as financeiro" do
      before { sign_in financeiro }

      it "updates and redirects" do
        patch invoice_path(invoice), params: { invoice: { client_name: "NOVO CLIENTE" } }
        expect(response).to redirect_to invoice_path(invoice)
      end

      it "renders edit with 422 on invalid params" do
        patch invoice_path(invoice), params: { invoice: { value: -1 } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it "blocks coordenador" do
      sign_in coordenador
      patch invoice_path(invoice), params: { invoice: { client_name: "X" } }
      expect(response).to redirect_to root_path
    end
  end

  # ── DELETE /invoices/:id ──────────────────────────────────────────────────
  describe "DELETE /invoices/:id" do
    it "admin can destroy and redirects to list" do
      sign_in admin
      delete invoice_path(invoice)
      expect(response).to redirect_to invoices_path
    end

    it "financeiro can destroy" do
      sign_in financeiro
      delete invoice_path(invoice)
      expect(response).to redirect_to invoices_path
      expect(flash[:notice]).to be_present
    end

    it "gestor cannot destroy" do
      sign_in gestor
      delete invoice_path(invoice)
      expect(response).to redirect_to root_path
    end
  end
end
