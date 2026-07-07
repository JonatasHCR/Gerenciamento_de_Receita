require 'rails_helper'

RSpec.describe "Reports", type: :request do
  describe "GET /reports" do
    it "abre para qualquer papel autenticado" do
      [:admin, :financeiro, :gestor, :coordenador].each do |role|
        sign_in create(:user, role)
        get reports_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /reports/open_invoices" do
    let(:client) { create(:client, name: "WWW Cliente") }
    let(:cc)     { create(:cost_center, client: client, cr_code: "OIREQ-1") }
    before { create(:invoice, cost_center: cc, value: 10_000) }

    it "gera PDF para admin (client_ids selecionados)" do
      sign_in create(:user, :admin)
      get open_invoices_report_path, params: { client_ids: [client.id] }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to include("faturas_em_aberto_")
      expect(response.body[0, 4]).to eq("%PDF")
    end

    it "gera Excel com output=xlsx" do
      sign_in create(:user, :financeiro)
      get open_invoices_report_path, params: { client_ids: [client.id], output: "xlsx" }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to include("spreadsheetml")
    end

    it "sem client_ids gera para todos" do
      sign_in create(:user, :admin)
      get open_invoices_report_path
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
    end

    it "bloqueia gestor e coordenador" do
      [:gestor, :coordenador].each do |role|
        sign_in create(:user, role)
        get open_invoices_report_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /reports/monthly" do
    context "unauthenticated" do
      it "redireciona para login" do
        get monthly_report_path
        expect(response).to redirect_to new_user_session_path
      end
    end

    context "as admin" do
      let(:user) { create(:user, :admin) }
      before { sign_in user }

      it "retorna um PDF" do
        get monthly_report_path, params: { month: "2026-06" }
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("application/pdf")
        expect(response.headers["Content-Disposition"]).to include("relatorio_20260601_20260630.pdf")
        expect(response.body[0, 4]).to eq("%PDF")
      end

      it "usa o mês atual quando nenhum é informado" do
        get monthly_report_path
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("application/pdf")
      end

      it "gera PDF por período quando start e end são informados" do
        get monthly_report_path, params: { start: "2026-05-01", end: "2026-06-30" }
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("application/pdf")
        expect(response.headers["Content-Disposition"]).to include("relatorio_20260501_20260630.pdf")
      end
    end

    context "as financeiro" do
      let(:user) { create(:user, :financeiro) }
      before { sign_in user }

      it "retorna um PDF" do
        get monthly_report_path, params: { month: "2026-06" }
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("application/pdf")
      end
    end

    context "as gestor" do
      let(:user) { create(:user, :gestor) }
      before { sign_in user }

      it "é bloqueado" do
        get monthly_report_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as coordenador" do
      let(:user) { create(:user, :coordenador) }
      before { sign_in user }

      it "é bloqueado" do
        get monthly_report_path
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
