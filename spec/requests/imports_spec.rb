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

  # ── POST /imports ─────────────────────────────────────────────────────────
  describe "POST /imports" do
    context "as admin" do
      before { sign_in admin }

      it "redirects back to new when no file sent" do
        post imports_path
        expect(response).to redirect_to new_import_path
        expect(flash[:alert]).to be_present
      end

      def stub_importer(result)
        importer = instance_double(Imports::ExcelImporter, call: result)
        allow(Imports::ExcelImporter).to receive(:new).and_return(importer)
      end

      def upload
        fixture_file_upload(
          Rails.root.join("spec/fixtures/files/sample.xlsx"),
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
    end

    it "blocks gestor" do
      sign_in gestor
      post imports_path
      expect(response).to redirect_to root_path
    end
  end
end
