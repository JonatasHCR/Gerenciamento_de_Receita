require "rails_helper"

# O login por email e senha deixou de existir: quem autentica é o Keycloak.
# Estes specs cobrem o callback do OmniAuth, que é onde ficam o gate de grupo e
# o provisionamento — cada um cobre uma maneira de o desenho falhar em silêncio.
RSpec.describe "Login via Keycloak", type: :request do
  SUB = "aaaaaaaa-0000-0000-0000-000000000001".freeze

  def stub_keycloak(sub: SUB, email: "fulano@ufc.com.br", nome: "Fulano da Silva",
                    grupos: ["/apps/receita"])
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:keycloak] = OmniAuth::AuthHash.new(
      provider: "keycloak",
      uid: sub,
      info: { email: email, name: nome },
      extra: { raw_info: { groups: grupos, auth_time: Time.current.to_i } }
    )
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:keycloak]
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:keycloak] = nil
    Rails.application.env_config.delete("omniauth.auth")
  end

  it "cria a conta local no primeiro acesso, com o menor papel" do
    stub_keycloak

    expect {
      get user_keycloak_omniauth_callback_path
    }.to change(User, :count).by(1)

    user = User.find_by(email: "fulano@ufc.com.br")
    expect(user.external_id).to eq(SUB)
    expect(user.role).to eq("coordenador")
    expect(response).to redirect_to(root_path)
  end

  it "barra quem não está no grupo /apps/receita e NÃO cria a conta" do
    # Sem esta checagem, qualquer pessoa do realm — inclusive quem só usa o
    # inventário — entraria aqui e ainda ganharia uma linha em `users`.
    stub_keycloak(grupos: ["/apps/inventario"])

    expect {
      get user_keycloak_omniauth_callback_path
    }.not_to change(User, :count)

    expect(response).to have_http_status(:redirect)
    expect(flash[:alert]).to match(/não tem acesso/i)
  end

  it "barra quem não está em grupo nenhum" do
    stub_keycloak(grupos: [])

    expect {
      get user_keycloak_omniauth_callback_path
    }.not_to change(User, :count)
  end

  it "reaproveita a conta anterior ao SSO pelo email, preservando id e papel" do
    # O ponto que preserva as FKs: há `user_cost_centers` e o `whodunnit` do
    # PaperTrail apontando para este id.
    antigo = create(:user, :admin, email: "antigo@ufc.com.br", external_id: nil)

    stub_keycloak(email: "antigo@ufc.com.br")

    expect {
      get user_keycloak_omniauth_callback_path
    }.not_to change(User, :count)

    antigo.reload
    expect(antigo.external_id).to eq(SUB)
    expect(antigo.role).to eq("admin"), "o papel local não pode ser rebaixado no primeiro login"
  end

  it "casa por email ignorando a caixa" do
    create(:user, email: "pessoa@ufc.com.br", external_id: nil)
    stub_keycloak(email: "Pessoa@UFC.com.br")

    expect {
      get user_keycloak_omniauth_callback_path
    }.not_to change(User, :count)
  end

  it "usa o external_id com precedência sobre o email" do
    # Depois de vinculado, trocar o email no Keycloak não cria conta nova.
    create(:user, email: "antes@ufc.com.br", external_id: SUB)
    stub_keycloak(email: "depois@ufc.com.br")

    expect {
      get user_keycloak_omniauth_callback_path
    }.not_to change(User, :count)
  end

  it "perder o grupo desativa a conta, sem apagar e sem mexer no papel" do
    # Há `user_cost_centers` e o `whodunnit` do PaperTrail apontando para a
    # linha; apagá-la levaria histórico junto. E `role` é papel, não acesso:
    # quem for readmitido volta como era.
    antigo = create(:user, :admin, email: "saiu@ufc.com.br", external_id: SUB)

    stub_keycloak(email: "saiu@ufc.com.br", grupos: ["/apps/inventario"])
    expect {
      get user_keycloak_omniauth_callback_path
    }.not_to change(User, :count)

    antigo.reload
    expect(antigo.ativo).to be(false)
    expect(antigo.role).to eq("admin"), "perder o acesso não pode rebaixar o papel"
  end

  it "devolver o grupo reativa a conta" do
    antigo = create(:user, email: "voltou@ufc.com.br", external_id: SUB)
    antigo.update_column(:ativo, false)

    stub_keycloak(email: "voltou@ufc.com.br")
    get user_keycloak_omniauth_callback_path

    expect(antigo.reload.ativo).to be(true)
    expect(response).to redirect_to(root_path)
  end

  it "conta inativa perde a sessão em aberto na requisição seguinte" do
    # A defesa para quem tenta acessar direto com uma sessão que ainda não
    # expirou: o Devise chama `active_for_authentication?` a cada requisição.
    user = create(:user, :admin)
    sign_in user
    get users_path
    expect(response).to have_http_status(:ok)

    user.update_column(:ativo, false)
    get users_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "a tela de sign_in não tem mais campo de senha" do
    get new_user_session_path
    expect(response.body).not_to include('type="password"')
    expect(response.body).to include("Entrar")
  end
end
