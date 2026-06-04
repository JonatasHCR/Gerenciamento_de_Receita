require 'rails_helper'

RSpec.describe "Users", type: :request do
  let(:admin)      { create(:user, :admin) }
  let(:financeiro) { create(:user, :financeiro) }
  let(:gestor)     { create(:user, :gestor) }
  let(:other_user) { create(:user) }

  let(:valid_params) do
    {
      user: {
        name:                  "Novo Usuário",
        email:                 "novo@ufc.com.br",
        role:                  "financeiro",
        password:              "senha12345",
        password_confirmation: "senha12345"
      }
    }
  end

  # ── Authentication ────────────────────────────────────────────────────────
  describe "unauthenticated" do
    it "GET /users redirects to sign in" do
      get users_path
      expect(response).to redirect_to new_user_session_path
    end

    it "GET /profile redirects to sign in" do
      get edit_profile_path
      expect(response).to redirect_to new_user_session_path
    end
  end

  # ── GET /users ────────────────────────────────────────────────────────────
  describe "GET /users" do
    it "returns 200 for admin" do
      sign_in admin
      get users_path
      expect(response).to have_http_status(:ok)
    end

    it "blocks financeiro" do
      sign_in financeiro
      get users_path
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to be_present
    end

    it "blocks gestor" do
      sign_in gestor
      get users_path
      expect(response).to redirect_to root_path
    end
  end

  # ── POST /users ───────────────────────────────────────────────────────────
  describe "POST /users" do
    it "admin creates user and redirects to list" do
      sign_in admin
      post users_path, params: valid_params
      expect(response).to redirect_to users_path
      expect(flash[:notice]).to be_present
    end

    it "renders new with 422 on invalid params" do
      sign_in admin
      post users_path, params: { user: { name: "", email: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "blocks non-admin" do
      sign_in financeiro
      post users_path, params: valid_params
      expect(response).to redirect_to root_path
    end
  end

  # ── PATCH /users/:id ──────────────────────────────────────────────────────
  describe "PATCH /users/:id" do
    it "admin can update any user" do
      sign_in admin
      patch user_path(other_user), params: { user: { name: "Atualizado" } }
      expect(response).to redirect_to users_path
    end

    it "non-admin cannot update other users" do
      sign_in financeiro
      patch user_path(other_user), params: { user: { name: "X" } }
      expect(response).to redirect_to root_path
    end

    it "user can update themselves (non-admin, own profile via users route)" do
      sign_in financeiro
      patch user_path(financeiro), params: { user: { name: "Meu Nome" } }
      expect(response).to redirect_to users_path
    end
  end

  # ── DELETE /users/:id ─────────────────────────────────────────────────────
  describe "DELETE /users/:id" do
    it "admin can delete other users" do
      sign_in admin
      delete user_path(other_user)
      expect(response).to redirect_to users_path
    end

    it "admin cannot delete themselves" do
      sign_in admin
      delete user_path(admin)
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to be_present
    end

    it "non-admin cannot delete" do
      sign_in financeiro
      delete user_path(other_user)
      expect(response).to redirect_to root_path
    end
  end

  # ── GET /profile ──────────────────────────────────────────────────────────
  describe "GET /profile" do
    it "returns 200 for any authenticated user" do
      [admin, financeiro, gestor].each do |user|
        sign_in user
        get edit_profile_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ── PATCH /profile ────────────────────────────────────────────────────────
  describe "PATCH /profile" do
    it "updates profile and redirects back to profile" do
      sign_in financeiro
      patch profile_path, params: { user: { name: "Novo Nome" } }
      expect(response).to redirect_to edit_profile_path
      expect(flash[:notice]).to be_present
    end

    it "non-admin cannot change their own role via profile" do
      sign_in financeiro
      patch profile_path, params: { user: { name: "Nome", role: "admin" } }
      expect(response).to redirect_to edit_profile_path
      financeiro.reload
      expect(financeiro.role).to eq("financeiro")
    end
  end
end
