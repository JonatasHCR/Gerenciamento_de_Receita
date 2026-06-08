require "rails_helper"

RSpec.describe "Maintenance", type: :request do
  let(:admin)      { create(:user, :admin, password: "admin123456", password_confirmation: "admin123456") }
  let(:financeiro) { create(:user, :financeiro) }

  describe "autorização (somente admin)" do
    it "redireciona não-admin do index" do
      sign_in financeiro
      get maintenance_path
      expect(response).not_to have_http_status(:ok)
    end

    it "permite admin no index" do
      sign_in admin
      get maintenance_path
      expect(response).to have_http_status(:ok)
    end

    it "bloqueia limpeza para não-admin" do
      sign_in financeiro
      create(:forecast_entry)
      expect {
        delete maintenance_cleanup_path, params: { target: "previsao", password: "x" }
      }.not_to change(ForecastEntry, :count)
    end
  end

  describe "limpeza" do
    before { sign_in admin }

    it "NÃO apaga com senha incorreta e avisa" do
      create(:forecast_entry)
      expect {
        delete maintenance_cleanup_path, params: { target: "previsao", password: "errada" }
      }.not_to change(ForecastEntry, :count)
      follow_redirect!
      expect(response.body).to include("Senha incorreta")
    end

    it "apaga previsões com senha correta e registra na auditoria" do
      create_list(:forecast_entry, 2)
      expect {
        delete maintenance_cleanup_path, params: { target: "previsao", password: "admin123456" }
      }.to change(ForecastEntry, :count).to(0)

      v = PaperTrail::Version.where(item_type: "Manutenção", event: "limpeza").last
      expect(v).to be_present
      expect(v.whodunnit).to eq(admin.id.to_s)
    end

    it "rejeita alvo inválido" do
      delete maintenance_cleanup_path, params: { target: "qualquer", password: "admin123456" }
      follow_redirect!
      expect(response.body).to include("inválido")
    end

    it "filtra por centro de custo (só apaga NFs do CC escolhido)" do
      cc1 = create(:cost_center)
      cc2 = create(:cost_center)
      keep = create(:invoice, cost_center: cc2)
      create(:invoice, cost_center: cc1)

      delete maintenance_cleanup_path,
        params: { target: "faturamento", cost_center_id: cc1.id, password: "admin123456" }

      expect(Invoice.exists?(keep.id)).to be(true)
      expect(Invoice.where(cost_center_id: cc1.id)).to be_empty
    end

    it "filtra previsão por mês/ano" do
      cc = create(:cost_center)
      create(:forecast_entry, cost_center: cc, month_year: "JUNHO/2026")
      keep = create(:forecast_entry, cost_center: cc, month_year: "JULHO/2026")

      delete maintenance_cleanup_path,
        params: { target: "previsao", month: "2026-06", password: "admin123456" }

      expect(ForecastEntry.where(month_year: "JUNHO/2026")).to be_empty
      expect(ForecastEntry.exists?(keep.id)).to be(true)
    end
  end

  describe "download" do
    before { sign_in admin }

    it "rejeita path traversal / arquivo inexistente" do
      get maintenance_download_path(file: "../config/database.yml")
      expect(response).to redirect_to(maintenance_path)
    end
  end

  describe "restore" do
    before { sign_in admin }

    it "não restaura com senha incorreta" do
      expect_any_instance_of(Maintenance::DatabaseRestore).not_to receive(:call)
      post maintenance_restore_path, params: { file: "x.dump", password: "errada" }
      follow_redirect!
      expect(response.body).to include("Senha incorreta")
    end

    it "restaura com senha correta e registra na auditoria" do
      allow_any_instance_of(Maintenance::DatabaseRestore).to receive(:call) do |svc|
        Maintenance::Audit.record(event: "restauração", user: admin, details: { "Arquivo" => "x.dump" })
        Rails.root.join("backups", "x.dump")
      end
      expect {
        post maintenance_restore_path, params: { file: "x.dump", password: "admin123456" }
      }.to change { PaperTrail::Version.where(item_type: "Manutenção", event: "restauração").count }.by(1)
      expect(response).to redirect_to(maintenance_path)
    end
  end

  describe "backup" do
    before { sign_in admin }

    it "dispara o backup (sem senha) e registra na auditoria" do
      file = Rails.root.join("backups", "manual_teste.dump")
      allow_any_instance_of(Maintenance::DatabaseBackup).to receive(:call) do |svc|
        Maintenance::Audit.record(event: "backup", user: admin, details: { "Arquivo" => "x.dump" })
        FileUtils.mkdir_p(file.dirname)
        File.write(file, "x")
        file
      end

      expect {
        post maintenance_backup_path
      }.to change { PaperTrail::Version.where(item_type: "Manutenção", event: "backup").count }.by(1)
      expect(response).to redirect_to(maintenance_path)
    ensure
      FileUtils.rm_f(file)
    end
  end
end
