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

      it "redirects to root on successful import" do
        importer = instance_double(Imports::ExcelImporter,
                                   call: double(success?: true, errors: []))
        allow(Imports::ExcelImporter).to receive(:new).and_return(importer)

        file = fixture_file_upload(
          Rails.root.join("spec/fixtures/files/sample.xlsx"),
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
        post imports_path, params: { file: file }
        expect(response).to redirect_to root_path
      end

      it "renders new with 422 on importer errors" do
        importer = instance_double(Imports::ExcelImporter,
                                   call: double(success?: false, errors: ["Erro na linha 3"]))
        allow(Imports::ExcelImporter).to receive(:new).and_return(importer)

        file = fixture_file_upload(
          Rails.root.join("spec/fixtures/files/sample.xlsx"),
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
        post imports_path, params: { file: file }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it "blocks gestor" do
      sign_in gestor
      post imports_path
      expect(response).to redirect_to root_path
    end
  end
end
