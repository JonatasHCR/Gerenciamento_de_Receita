require "rails_helper"

RSpec.describe "Reconferência do grupo durante a sessão", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  SUB_REVAL = "bbbbbbbb-0000-0000-0000-000000000002".freeze

  def entrar(grupos: ["/apps/receita"], email: "fulano@ufc.com.br")
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:keycloak] = OmniAuth::AuthHash.new(
      provider: "keycloak",
      uid: SUB_REVAL,
      info: { email: email, name: "Fulano" },
      credentials: { refresh_token: "refresh-inicial", expires_at: Time.current.to_i + 300 },
      extra: { raw_info: { groups: grupos, auth_time: Time.current.to_i } }
    )
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:keycloak]
    get user_keycloak_omniauth_callback_path
    User.find_by(email: email)
  end

  def vencer_o_token
    # A sessão não é editável do teste; avançar o relógio vence o token guardado.
    travel(6.minutes)
  end

  def keycloak_devolve(grupos:)
    resultado = Keycloak::Revalidacao::Resultado.new(
      ok: true,
      grupos: grupos,
      refresh_token: "refresh-novo",
      expira_em: Time.current.to_i + 300
    )
    allow(Keycloak::Revalidacao).to receive(:renovar).and_return(resultado)
  end

  def keycloak_falha
    resultado = Keycloak::Revalidacao::Resultado.new(ok: false, erro: "sem resposta")
    allow(Keycloak::Revalidacao).to receive(:renovar).and_return(resultado)
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:keycloak] = nil
    Rails.application.env_config.delete("omniauth.auth")
  end

  it "não conversa com o Keycloak enquanto o token está fresco" do
    entrar
    expect(Keycloak::Revalidacao).not_to receive(:renovar)
    get root_path
    expect(response).to have_http_status(:ok)
  end

  it "renova quando o token está perto de vencer, e segue em frente" do
    entrar
    keycloak_devolve(grupos: ["/apps/receita"])

    vencer_o_token
    get root_path

    expect(Keycloak::Revalidacao).to have_received(:renovar)
    expect(response).to have_http_status(:ok)
  end

  it "expulsa e desativa quem perdeu o grupo, sem esperar o próximo login" do
    user = entrar
    keycloak_devolve(grupos: ["/apps/inventario"])

    vencer_o_token
    get root_path

    expect(response).to redirect_to(new_user_session_path)
    expect(user.reload.ativo).to be(false)
  end

  it "não apaga a conta de quem perdeu o grupo" do
    user = entrar
    keycloak_devolve(grupos: [])

    vencer_o_token
    get root_path

    expect(User.find_by(id: user.id)).to be_present
  end

  it "derruba a sessão quando o Keycloak não responde" do
    entrar
    keycloak_falha

    vencer_o_token
    get root_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "atualiza os grupos do seletor Sistemas" do
    entrar(grupos: ["/apps/receita", "/apps/inventario"])
    keycloak_devolve(grupos: ["/apps/receita"])

    vencer_o_token
    get root_path

    expect(response.body).not_to include("Inventario")
  end

  it "deixa a conta mestra entrar mesmo sem o grupo" do
    mestre = "admin@ufc.com.br"
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ADMIN_MESTRE_EMAIL").and_return(mestre)

    entrar(email: mestre)
    keycloak_devolve(grupos: [])

    vencer_o_token
    get root_path

    expect(response).to have_http_status(:ok)
  end
end
