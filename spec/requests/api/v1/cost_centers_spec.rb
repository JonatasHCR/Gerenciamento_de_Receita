require "rails_helper"

RSpec.describe "API v1 — cost centers", type: :request do
  let(:token) { "token-de-teste-para-o-sync" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  before { allow(ENV).to receive(:[]).and_call_original }

  def com_token_configurado
    allow(ENV).to receive(:[]).with("SYNC_API_TOKEN").and_return(token)
  end

  describe "autenticação" do
    it "recusa sem token" do
      com_token_configurado
      get "/api/v1/cost_centers"
      expect(response).to have_http_status(:unauthorized)
    end

    it "recusa com token errado" do
      com_token_configurado
      get "/api/v1/cost_centers", headers: { "Authorization" => "Bearer errado" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "recusa uma sessão de usuário comum — não é gente que chama esta API" do
      com_token_configurado
      sign_in create(:user, :admin)
      get "/api/v1/cost_centers"
      expect(response).to have_http_status(:unauthorized)
    end

    it "avisa em vez de aceitar qualquer coisa quando o token não está configurado" do
      allow(ENV).to receive(:[]).with("SYNC_API_TOKEN").and_return(nil)
      get "/api/v1/cost_centers", headers: headers
      expect(response).to have_http_status(:service_unavailable)
    end

    it "aceita com o token correto" do
      com_token_configurado
      get "/api/v1/cost_centers", headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/v1/cost_centers" do
    before { com_token_configurado }

    it "devolve o cliente aninhado e o coordinator_list já separado" do
      cliente = create(:client, name: "ACME", full_name: "ACME Engenharia Ltda")
      create(:cost_center, cr_code: "CASC-1", description: "Obra X",
             coordinator: "Ana Souza / Bruno Lima", client: cliente)

      get "/api/v1/cost_centers", headers: headers
      cc = response.parsed_body["cost_centers"].first

      expect(cc["cr_code"]).to eq("CASC-1")
      expect(cc["client"]).to eq({ "name" => "ACME", "full_name" => "ACME Engenharia Ltda" })
      # É método Ruby (split por " / "), não coluna — `as_json` não traria.
      expect(cc["coordinator_list"]).to eq(["Ana Souza", "Bruno Lima"])
    end

    it "vê TODOS os centros de custo, ignorando o escopo de coordenador" do
      # O CostCenterPolicy::Scope filtra por coordenador; essa regra existe para
      # gente. Se valesse aqui, a cópia do inventário nasceria incompleta.
      create_list(:cost_center, 3)

      get "/api/v1/cost_centers", headers: headers
      expect(response.parsed_body["count"]).to eq(3)
    end

    it "filtra por updated_since e devolve a marca d'água do último registro" do
      antigo = create(:cost_center)
      antigo.update_column(:updated_at, 2.days.ago)
      recente = create(:cost_center)
      recente.update_column(:updated_at, 1.minute.ago)

      get "/api/v1/cost_centers",
          params: { updated_since: 1.day.ago.iso8601 }, headers: headers

      corpo = response.parsed_body
      expect(corpo["cost_centers"].map { |c| c["cr_code"] }).to eq([recente.cr_code])
      expect(Time.zone.parse(corpo["watermark"])).to be_within(1.second).of(recente.reload.updated_at)
    end

    it "sem updated_since devolve tudo — é a primeira carga" do
      create_list(:cost_center, 2)
      get "/api/v1/cost_centers", headers: headers
      expect(response.parsed_body["count"]).to eq(2)
    end

    it "sinaliza has_more quando a página enche" do
      create_list(:cost_center, 3)
      get "/api/v1/cost_centers", params: { limit: 2 }, headers: headers

      expect(response.parsed_body["count"]).to eq(2)
      expect(response.parsed_body["has_more"]).to be true
    end

    it "ignora updated_since inválido em vez de estourar" do
      create(:cost_center)
      get "/api/v1/cost_centers", params: { updated_since: "ontem" }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["count"]).to eq(1)
    end
  end

  describe "GET /api/v1/cost_centers/deletions" do
    before { com_token_configurado }

    it "lista os CCs apagados, com o cr_code recuperado do PaperTrail" do
      # Não há soft-delete no schema: a tabela `versions` é a única trilha de
      # exclusão. Sem isto, um CC apagado aqui ficaria para sempre lá.
      cc = create(:cost_center, cr_code: "SUMIU-1")
      cc.destroy

      get "/api/v1/cost_centers/deletions", headers: headers

      exclusoes = response.parsed_body["deletions"]
      expect(exclusoes.size).to eq(1)
      expect(exclusoes.first["cr_code"]).to eq("SUMIU-1")
      expect(exclusoes.first["deleted_at"]).to be_present
    end

    it "não confunde exclusão de CC com exclusão de outros modelos" do
      create(:client).destroy
      get "/api/v1/cost_centers/deletions", headers: headers
      expect(response.parsed_body["count"]).to eq(0)
    end

    it "filtra por since" do
      antigo = create(:cost_center); antigo.destroy
      PaperTrail::Version.last.update_column(:created_at, 2.days.ago)
      novo = create(:cost_center, cr_code: "RECEM-1"); novo.destroy

      get "/api/v1/cost_centers/deletions",
          params: { since: 1.day.ago.iso8601 }, headers: headers

      expect(response.parsed_body["deletions"].map { |d| d["cr_code"] }).to eq(["RECEM-1"])
    end
  end

  describe "roteamento" do
    it "a rota da API não é engolida pelo catch-all *unmatched" do
      com_token_configurado
      get "/api/v1/cost_centers", headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")
    end
  end
end
