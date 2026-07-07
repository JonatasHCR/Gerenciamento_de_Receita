require 'rails_helper'

RSpec.describe "Imports", type: :request do
  let(:admin)      { create(:user, :admin) }
  let(:financeiro) { create(:user, :financeiro) }
  let(:gestor)     { create(:user, :gestor) }
  let(:coordenador){ create(:user, :coordenador) }

  # ── Authentication ────────────────────────────────────────────────────────
  describe "unauthenticated" do
    it "GET /imports/new redirects to sign in" do
      get new_import_path
      expect(response).to redirect_to new_user_session_path
    end
  end

  # ── GET /imports/new ──────────────────────────────────────────────────────
  describe "GET /imports/new" do
    it "returns 200 for admin" do
      sign_in admin
      get new_import_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for financeiro" do
      sign_in financeiro
      get new_import_path
      expect(response).to have_http_status(:ok)
    end

    it "blocks gestor" do
      sign_in gestor
      get new_import_path
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to be_present
    end

    it "blocks coordenador" do
      sign_in coordenador
      get new_import_path
      expect(response).to redirect_to root_path
    end
  end

  # ── GET /imports/template ─────────────────────────────────────────────────
  describe "GET /imports/template" do
    it "gera o modelo só com as abas dos alvos marcados" do
      sign_in admin
      get template_imports_path, params: { targets: %w[faturamento recebimento] }
      expect(response).to have_http_status(:ok)
      path = Rails.root.join("tmp", "tmpl_req_#{SecureRandom.hex(4)}.xlsx")
      File.binwrite(path, response.body)
      expect(Roo::Spreadsheet.open(path.to_s).sheets).to contain_exactly("FATURAMENTO", "RECEBIMENTO")
      File.delete(path)
    end

    it "não inclui a aba USUARIOS para financeiro" do
      sign_in financeiro
      get template_imports_path, params: { targets: %w[centros usuarios] }
      path = Rails.root.join("tmp", "tmpl_req_#{SecureRandom.hex(4)}.xlsx")
      File.binwrite(path, response.body)
      expect(Roo::Spreadsheet.open(path.to_s).sheets).to eq(["CADASTRO CENTRO DE CUSTO"])
      File.delete(path)
    end

    context "com o gerador stubbado" do
      before do
        allow_any_instance_of(Imports::TemplateGenerator)
          .to receive(:call)
          .and_return("fake xlsx binary data")
      end

    it "returns xlsx file for admin" do
      sign_in admin
      get template_imports_path
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("spreadsheetml")
    end

    it "returns xlsx file for financeiro" do
      sign_in financeiro
      get template_imports_path
      expect(response).to have_http_status(:ok)
    end

    it "blocks gestor" do
      sign_in gestor
      get template_imports_path
      expect(response).to redirect_to root_path
    end
    end
  end

  # ── POST /imports ─────────────────────────────────────────────────────────
  describe "POST /imports" do
    context "as admin" do
      before { sign_in admin }

      it "redirects back to new when no file sent" do
        post imports_path
        expect(response).to redirect_to new_import_path
        expect(flash[:alert]).to be_present
      end

      it "rejeita upload com extensão inválida (não .xlsx/.xls)" do
        Tempfile.create(["nota", ".txt"]) do |tmp|
          tmp.write("x"); tmp.rewind
          post imports_path, params: { file: Rack::Test::UploadedFile.new(tmp.path, "text/plain") }
        end
        expect(response).to redirect_to new_import_path
        expect(flash[:alert]).to include("Formato inválido")
      end

      it "rejeita upload acima do limite de tamanho" do
        Tempfile.create(["grande", ".xlsx"]) do |tmp|
          tmp.write("0" * (ImportsController::MAX_UPLOAD_BYTES + 1)); tmp.rewind
          post imports_path, params: {
            file: Rack::Test::UploadedFile.new(tmp.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
          }
        end
        expect(response).to redirect_to new_import_path
        expect(flash[:alert]).to include("muito grande")
      end

      def stub_importer(result)
        importer = instance_double(Imports::ExcelImporter, call: result)
        allow(Imports::ExcelImporter).to receive(:new).and_return(importer)
      end

      def upload
        # O conteúdo é irrelevante (o ExcelImporter é stubbado); só precisa existir.
        # Gerado aqui porque *.xlsx é gitignored e não vai pro checkout do CI.
        fixture = Rails.root.join("spec/fixtures/files/sample.xlsx")
        FileUtils.mkdir_p(fixture.dirname)
        File.write(fixture, "stub") unless File.exist?(fixture)
        fixture_file_upload(
          fixture,
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
      end

      it "redirects to root on fully clean import" do
        stub_importer(Imports::ExcelImporter::Result.new(created: 5, updated: 0, errors: [], fatal_error: nil))
        post imports_path, params: { file: upload }
        expect(response).to redirect_to root_path
        expect(flash[:notice]).to include("5")
      end

      it "renders summary with 422 on partial success (imports good rows, lists errors)" do
        result = Imports::ExcelImporter::Result.new(
          created: 3, updated: 0,
          errors: ["Faturamento — linha 7 (NF 123): centro de custo X não encontrado."],
          fatal_error: nil
        )
        stub_importer(result)
        post imports_path, params: { file: upload }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("3 registro")
        expect(response.body).to include("linha 7")
      end

      it "renders new with 422 and alert on fatal error" do
        result = Imports::ExcelImporter::Result.new(
          created: 0, updated: 0, errors: [], fatal_error: "Não foi possível processar o arquivo: boom"
        )
        stub_importer(result)
        post imports_path, params: { file: upload }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Não foi possível processar")
      end

      it "importação parcial chama o ExcelImporter só com as abas marcadas" do
        clean = Imports::ExcelImporter::Result.new(created: 1, updated: 0, errors: [], fatal_error: nil)
        importer = instance_double(Imports::ExcelImporter, call: clean)
        expect(Imports::ExcelImporter).to receive(:new).with(anything, only: [:invoices]).and_return(importer)
        post imports_path, params: { file: upload, targets: ["faturamento"] }
        expect(response).to redirect_to root_path
      end

      it "importa usuários (só admin) via UserImporter" do
        clean = Imports::ExcelImporter::Result.new(created: 2, updated: 0, errors: [], fatal_error: nil)
        importer = instance_double(Imports::UserImporter, call: clean)
        expect(Imports::UserImporter).to receive(:new).and_return(importer)
        post imports_path, params: { file: upload, targets: ["usuarios"] }
        expect(response).to redirect_to root_path
      end
    end

    it "barra importação de usuários para financeiro" do
      sign_in financeiro
      fixture = Rails.root.join("spec/fixtures/files/sample.xlsx")
      FileUtils.mkdir_p(fixture.dirname)
      File.write(fixture, "stub") unless File.exist?(fixture)
      upload = fixture_file_upload(fixture, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      expect(Imports::UserImporter).not_to receive(:new)
      post imports_path, params: { file: upload, targets: ["usuarios"] }
      expect(response).to redirect_to root_path
    end

    it "blocks gestor" do
      sign_in gestor
      post imports_path
      expect(response).to redirect_to root_path
    end
  end
end
