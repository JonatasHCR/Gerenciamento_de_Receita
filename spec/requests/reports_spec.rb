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

    it "renderiza os três níveis do filtro em cascata com os dados de estreitamento" do
      client = create(:client, name: "Cliente Cascata")
      cc     = create(:cost_center, client: client, cr_code: "CASC-1", coordinator: "Bruno Lima / Ana Souza")

      sign_in create(:user, :admin)
      get reports_path

      expect(response.body).to include('data-level="coordenador"')
      expect(response.body).to include('data-level="cliente"')
      expect(response.body).to include('data-level="centro_custo"')
      expect(response.body).to include('name="coordinator_names[]" value="Bruno Lima"')
      expect(response.body).to include("data-client-id=\"#{cc.client_id}\"")
      expect(response.body).to include("Bruno Lima&quot;,&quot;Ana Souza")
    end

  end

  describe "GET /reports/movement" do
    let(:client) { create(:client, name: "WWW Cliente") }
    let(:cc)     { create(:cost_center, client: client, cr_code: "MVREQ-1", coordinator: "Bruno Lima") }
    before { create(:invoice, cost_center: cc, value: 10_000) }

    it "gera PDF para admin (client_ids selecionados)" do
      sign_in create(:user, :admin)
      get movement_report_path, params: { client_ids: [client.id], tipo: "faturamento" }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to include("movimentacao_")
      expect(response.body[0, 4]).to eq("%PDF")
    end

    it "gera PDF de recebimento com período" do
      sign_in create(:user, :admin)
      get movement_report_path, params: { tipo: "recebimento", start: "2026-06-01", end: "2026-06-30" }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
    end

    it "gera PDF agrupado por coordenador com seleção de CC" do
      sign_in create(:user, :admin)
      get movement_report_path, params: { tipo: "ambos", group_by: "coordenador",
                                          coordinator_names: ["Bruno Lima"], cost_center_ids: [cc.id] }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
    end

    it "gera Excel com output=xlsx" do
      sign_in create(:user, :financeiro)
      get movement_report_path, params: { client_ids: [client.id], output: "xlsx" }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to include("spreadsheetml")
    end

    it "sem filtros gera para todos" do
      sign_in create(:user, :admin)
      get movement_report_path
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
    end

    it "somente faturas em aberto" do
      sign_in create(:user, :admin)
      get movement_report_path, params: { tipo: "faturamento", only_open: "1" }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
    end

    it "bloqueia gestor e coordenador" do
      [:gestor, :coordenador].each do |role|
        sign_in create(:user, role)
        get movement_report_path
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

      it "gera PDF agrupado por coordenador" do
        get monthly_report_path, params: { month: "2026-06", group_by: "coordenador" }
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
