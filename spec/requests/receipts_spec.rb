require 'rails_helper'

RSpec.describe "Receipts", type: :request do
  let(:admin)      { create(:user, :admin) }
  let(:financeiro) { create(:user, :financeiro) }
  let(:gestor)     { create(:user, :gestor) }
  let(:invoice)    { create(:invoice, value: 5_000) }
  let(:receipt)    { create(:receipt, invoice: invoice, value: 1_000) }

  let(:valid_params)   { { receipt: { payment_date: Date.current, value: 1_000 } } }
  let(:invalid_params) { { receipt: { payment_date: nil,          value: -1   } } }

  # ── Authentication ────────────────────────────────────────────────────────
  describe "unauthenticated" do
    it "GET /receipts redirects to sign in" do
      get receipts_path
      expect(response).to redirect_to new_user_session_path
    end

    it "GET new redirects to sign in" do
      get new_invoice_receipt_path(invoice)
      expect(response).to redirect_to new_user_session_path
    end
  end

  # ── GET /receipts ─────────────────────────────────────────────────────────
  describe "GET /receipts" do
    it "returns 200 for financeiro" do
      sign_in financeiro
      get receipts_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for admin" do
      sign_in admin
      get receipts_path
      expect(response).to have_http_status(:ok)
    end

    it "blocks gestor" do
      sign_in gestor
      get receipts_path
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to be_present
    end

    it "filters by month" do
      sign_in financeiro
      get receipts_path, params: { month: receipt.payment_date.strftime("%Y-%m") }
      expect(response).to have_http_status(:ok)
    end

    it "filters by cost_center_id" do
      sign_in financeiro
      get receipts_path, params: { cost_center_id: invoice.cost_center_id }
      expect(response).to have_http_status(:ok)
    end
  end

  # ── GET /invoices/:id/receipts/new ────────────────────────────────────────
  describe "GET /invoices/:invoice_id/receipts/new" do
    it "returns 200 for financeiro" do
      sign_in financeiro
      get new_invoice_receipt_path(invoice)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for admin" do
      sign_in admin
      get new_invoice_receipt_path(invoice)
      expect(response).to have_http_status(:ok)
    end

    it "blocks gestor" do
      sign_in gestor
      get new_invoice_receipt_path(invoice)
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to be_present
    end
  end

  # ── POST /invoices/:id/receipts ───────────────────────────────────────────
  describe "POST /invoices/:invoice_id/receipts" do
    context "as financeiro" do
      before { sign_in financeiro }

      it "creates receipt and redirects to invoice" do
        post invoice_receipts_path(invoice), params: valid_params
        expect(response).to redirect_to invoice_path(invoice)
        expect(flash[:notice]).to be_present
      end

      it "renders new with 422 on invalid params" do
        post invoice_receipts_path(invoice), params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "renders new with 422 when value exceeds balance" do
        post invoice_receipts_path(invoice), params: { receipt: { payment_date: Date.current, value: 99_999 } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it "blocks gestor" do
      sign_in gestor
      post invoice_receipts_path(invoice), params: valid_params
      expect(response).to redirect_to root_path
    end
  end

  # ── PATCH /receipts/:id ───────────────────────────────────────────────────
  describe "PATCH /receipts/:id" do
    context "as financeiro" do
      before { sign_in financeiro }

      it "updates and redirects to invoice" do
        patch receipt_path(receipt), params: { receipt: { value: 500 } }
        expect(response).to redirect_to invoice_path(invoice)
      end
    end

    it "blocks gestor" do
      sign_in gestor
      patch receipt_path(receipt), params: { receipt: { value: 500 } }
      expect(response).to redirect_to root_path
    end
  end

  # ── DELETE /receipts/:id ──────────────────────────────────────────────────
  describe "DELETE /receipts/:id" do
    it "admin can destroy" do
      sign_in admin
      delete receipt_path(receipt)
      expect(response).to redirect_to invoice_path(invoice)
    end

    it "financeiro can destroy" do
      sign_in financeiro
      delete receipt_path(receipt)
      expect(response).to redirect_to invoice_path(invoice)
      expect(flash[:notice]).to be_present
    end
  end
end
