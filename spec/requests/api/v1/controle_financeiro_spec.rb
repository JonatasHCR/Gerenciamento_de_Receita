require "rails_helper"

RSpec.describe "API v1 — espelho para o Controle Financeiro", type: :request do
  let(:token) { "token-de-teste-para-o-sync" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("SYNC_API_TOKEN").and_return(token)
  end

  %w[clients invoices receipts adjustments forecast_entries deletions status].each do |recurso|
    it "recusa /api/v1/#{recurso} sem token" do
      get "/api/v1/#{recurso}"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/invoices" do
    it "traz o CR junto da NF e o valor como texto decimal" do
      cc = create(:cost_center, cr_code: "4561")
      create(:invoice, cost_center: cc, number: "701", value: 1234.56, kind: :reajuste)

      get "/api/v1/invoices", headers: headers
      nf = response.parsed_body["invoices"].first

      expect(nf).to include("cr_code" => "4561", "number" => "701", "kind" => "reajuste", "value" => "1234.56")
      expect(nf["cost_center_id"]).to eq(cc.id)
    end

    it "pagina e devolve a marca d'água do último registro" do
      create_list(:invoice, 3)

      get "/api/v1/invoices", params: { limit: 2 }, headers: headers
      corpo = response.parsed_body
      expect(corpo["count"]).to eq(2)
      expect(corpo["has_more"]).to be(true)
      expect(corpo["watermark"]).to eq(Invoice.order(:updated_at, :id).second.updated_at.iso8601(6))

      get "/api/v1/invoices", params: { limit: 2, offset: 2 }, headers: headers
      expect(response.parsed_body["count"]).to eq(1)
    end

    it "filtra por updated_since" do
      antiga = create(:invoice)
      antiga.update_column(:updated_at, 2.days.ago)
      recente = create(:invoice)

      get "/api/v1/invoices", params: { updated_since: 1.day.ago.iso8601 }, headers: headers
      expect(response.parsed_body["invoices"].map { |n| n["id"] }).to eq([recente.id])
    end
  end

  describe "GET /api/v1/receipts e /forecast_entries" do
    it "devolve recebimentos com a NF de origem" do
      recebimento = create(:receipt)
      get "/api/v1/receipts", headers: headers
      expect(response.parsed_body["receipts"].first).to include("id" => recebimento.id, "invoice_id" => recebimento.invoice_id)
    end

    it "devolve a previsão mensal" do
      create(:forecast_entry, month_year: "JUNHO/2026", forecasted_total: 1000)
      get "/api/v1/forecast_entries", headers: headers
      expect(response.parsed_body["forecast_entries"].first).to include("month_year" => "JUNHO/2026", "forecasted_total" => "1000.0")
    end
  end

  describe "GET /api/v1/adjustments" do
    it "atualiza updated_at dos aditivos reencadeados, para o sync incremental enxergar" do
      cc = create(:cost_center, value: 100_000)
      primeiro = create(:adjustment, cost_center: cc, new_value: 110_000)
      segundo = create(:adjustment, cost_center: cc, new_value: 120_000)
      segundo.update_column(:updated_at, 2.days.ago)

      primeiro.update!(new_value: 115_000)

      get "/api/v1/adjustments", params: { updated_since: 1.day.ago.iso8601 }, headers: headers
      ids = response.parsed_body["adjustments"].map { |a| a["id"] }
      expect(ids).to include(segundo.id)
    end
  end

  describe "GET /api/v1/deletions" do
    it "lista exclusões por tipo, lidas do PaperTrail" do
      nf = create(:invoice)
      id = nf.id
      nf.destroy!

      get "/api/v1/deletions", params: { types: "Invoice" }, headers: headers
      exclusao = response.parsed_body["deletions"].first
      expect(exclusao).to include("item_type" => "Invoice", "item_id" => id)
    end

    it "ignora tipos desconhecidos em vez de expor outras tabelas" do
      get "/api/v1/deletions", params: { types: "User" }, headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe "paginação pela última linha lida" do
    # Lê como o Controle Financeiro: segue watermark + last_id até has_more=false.
    def ler_tudo(rota, chave, marca, limite, extra = {})
      vistos = []
      consulta = { limit: limite }.merge(extra)
      50.times do
        get rota, params: consulta, headers: headers
        corpo = response.parsed_body
        vistos += corpo[chave].map { |x| x["id"] || x["item_id"] }
        return vistos unless corpo["has_more"]

        consulta = { limit: limite, marca => corpo["watermark"], after_id: corpo["last_id"] }.merge(extra)
      end
      raise "a paginação não terminou"
    end

    it "cobre todas as NFs mesmo com o mesmo updated_at (o id desempata)" do
      nfs = create_list(:invoice, 5)
      Invoice.update_all(updated_at: Time.zone.parse("2026-01-10 10:00:00.123456"))

      vistos = ler_tudo("/api/v1/invoices", "invoices", :updated_since, 2)
      expect(vistos).to eq(nfs.map(&:id).sort)
    end

    it "pagina as exclusões além do limite, que antes voltavam sempre na primeira página" do
      ids = create_list(:invoice, 5).map(&:id)
      Invoice.find_each(&:destroy!)

      vistos = ler_tudo("/api/v1/deletions", "deletions", :since, 2, { types: "Invoice" })
      expect(vistos).to match_array(ids)

      get "/api/v1/deletions", params: { types: "Invoice", limit: 2, offset: 2 }, headers: headers
      segunda = response.parsed_body["deletions"].map { |x| x["item_id"] }
      expect(segunda).to eq(ids.sort[2, 2])
    end
  end

  describe "GET /api/v1/status" do
    it "dá contagem e soma de cada tabela para a reconciliação" do
      create(:invoice, value: 10)
      create(:invoice, value: 5.5)

      get "/api/v1/status", headers: headers
      expect(response.parsed_body["invoices"]).to include("count" => 2, "sum" => "15.5")
    end
  end

  describe "GET /api/v1/cost_centers" do
    it "agora traz id, valor e participação para o Controle Financeiro" do
      create(:cost_center, cr_code: "4602", value: 3_250_000, participation: 0.6)
      get "/api/v1/cost_centers", headers: headers
      cc = response.parsed_body["cost_centers"].first
      expect(cc).to include("cr_code" => "4602", "value" => "3250000.0", "participation" => "0.6")
      expect(cc["id"]).to be_present
    end
  end

  it "rota inexistente dentro de /api/v1 continua caindo no 404" do
    get "/api/v1/nao_existe", headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it "informa se o contrato está ativo" do
    create(:cost_center, cr_code: "7001").update!(active: false)
    get "/api/v1/cost_centers", headers: headers
    expect(response.parsed_body["cost_centers"].first).to include("cr_code" => "7001", "active" => false)
  end
end
