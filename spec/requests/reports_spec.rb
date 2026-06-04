require 'rails_helper'

RSpec.describe "Reports", type: :request do
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
        expect(response.headers["Content-Disposition"]).to include("relatorio_2026_06.pdf")
        expect(response.body[0, 4]).to eq("%PDF")
      end

      it "usa o mês atual quando nenhum é informado" do
        get monthly_report_path
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("application/pdf")
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
