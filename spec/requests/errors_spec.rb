require 'rails_helper'

RSpec.describe "Errors", type: :request do
  it "responde 404 em rota inexistente sem listar as rotas" do
    get "/rota-que-nao-existe"
    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("não encontrada")
    expect(response.body).not_to include("Routing Error")
  end

  it "responde 404 para usuário autenticado também" do
    sign_in create(:user, :admin)
    get "/outra-rota-inexistente"
    expect(response).to have_http_status(:not_found)
  end
end
