require 'rails_helper'

RSpec.describe "AuditLogs", type: :request do
  let(:admin)      { create(:user, :admin) }
  let(:financeiro) { create(:user, :financeiro) }
  let(:gestor)     { create(:user, :gestor) }
  let(:coordenador){ create(:user, :coordenador) }

  # ── Authentication ────────────────────────────────────────────────────────
  describe "unauthenticated" do
    it "GET /audit_logs redirects to sign in" do
      get audit_logs_path
      expect(response).to redirect_to new_user_session_path
    end
  end

  # ── GET /audit_logs ───────────────────────────────────────────────────────
  describe "GET /audit_logs" do
    it "returns 200 for admin" do
      sign_in admin
      get audit_logs_path
      expect(response).to have_http_status(:ok)
    end

    it "blocks financeiro" do
      sign_in financeiro
      get audit_logs_path
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to be_present
    end

    it "blocks gestor" do
      sign_in gestor
      get audit_logs_path
      expect(response).to redirect_to root_path
    end

    it "blocks coordenador" do
      sign_in coordenador
      get audit_logs_path
      expect(response).to redirect_to root_path
    end
  end

  # ── GET /audit_logs with filters ──────────────────────────────────────────
  describe "GET /audit_logs with filters" do
    before { sign_in admin }

    it "filters by item_type" do
      get audit_logs_path, params: { item_type: "Invoice" }
      expect(response).to have_http_status(:ok)
    end

    it "filters by event" do
      get audit_logs_path, params: { event: "create" }
      expect(response).to have_http_status(:ok)
    end

    it "filters by user_id" do
      get audit_logs_path, params: { user_id: admin.id }
      expect(response).to have_http_status(:ok)
    end
  end

  # ── GET /audit_logs/:id ───────────────────────────────────────────────────
  describe "GET /audit_logs/:id" do
    let!(:version) do
      invoice = create(:invoice)
      invoice.versions.last
    end

    it "returns 200 for admin" do
      sign_in admin
      get audit_log_path(version)
      expect(response).to have_http_status(:ok)
    end

    it "blocks financeiro" do
      sign_in financeiro
      get audit_log_path(version)
      expect(response).to redirect_to root_path
    end
  end
end
