require 'rails_helper'

RSpec.describe "Dashboard", type: :request do
  describe "GET /" do
    context "unauthenticated" do
      it "redirects to sign in" do
        get root_path
        expect(response).to redirect_to new_user_session_path
      end
    end

    context "as admin" do
      let(:user) { create(:user, :admin) }
      before { sign_in user }

      it "returns 200" do
        get root_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as financeiro" do
      let(:user) { create(:user, :financeiro) }
      before { sign_in user }

      it "returns 200" do
        get root_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as gestor" do
      let(:user) { create(:user, :gestor) }
      before { sign_in user }

      it "returns 200 (dashboard is accessible to all roles)" do
        get root_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as coordenador" do
      let(:user) { create(:user, :coordenador) }
      before { sign_in user }

      it "returns 200" do
        get root_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "with month filter" do
      let(:user) { create(:user, :admin) }
      before { sign_in user }

      it "returns 200 for valid month param" do
        get root_path, params: { month: "2026-06" }
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
