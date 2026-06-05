require "rails_helper"

RSpec.describe "Sessions (login)", type: :request do
  let(:user) { create(:user, :admin, password: "senha123456", password_confirmation: "senha123456") }

  it "exibe mensagem de erro ao errar a senha" do
    post user_session_path, params: { user: { email: user.email, password: "errada" } }
    expect(response.body).to include("inválid") # "E-mail ou senha inválidos."
  end

  it "exibe mensagem de erro para usuário inexistente" do
    post user_session_path, params: { user: { email: "naoexiste@ufc.com.br", password: "x" } }
    expect(response.body).to include("inválid")
  end

  it "loga com credenciais corretas" do
    post user_session_path, params: { user: { email: user.email, password: "senha123456" } }
    expect(response).to redirect_to(root_path)
  end
end
