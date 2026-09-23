Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  # O `devise_for` gera as rotas de sessao a partir dos MODULOS do modelo. Sem o
  # :database_authenticatable ele nao gera mais `new_user_session` nem
  # `destroy_user_session` — e o layout e metade dos specs dependem das duas.
  # Declaradas a mao, com os mesmos nomes de sempre.
  devise_scope :user do
    get    "users/sign_in",  to: "users/sessions#new",     as: :new_user_session
    delete "users/sign_out", to: "users/sessions#destroy", as: :destroy_user_session
  end

  # /users/sign_in continua existindo — nao ha mais formulario de senha, so um
  # botao que POSTa para o Keycloak. Precisa ser POST: a gem
  # omniauth-rails_csrf_protection recusa iniciar o fluxo por GET.
  #
  # ATENCAO: qualquer rota precisa ser declarada ANTES do
  # `match "*unmatched"` la embaixo — o catch-all engole tudo o que vier depois.

  authenticated :user do
    root to: "dashboard#index", as: :authenticated_root
  end

  root to: redirect("/users/sign_in")

  get  "up" => "rails/health#show", as: :rails_health_check

  get   "profile",        to: "users#profile_edit",   as: :edit_profile
  patch "profile",        to: "users#profile_update", as: :profile
  put   "profile",        to: "users#profile_update"

  resources :clients
  resources :cost_centers do
    resources :adjustments, only: [:create, :edit, :update, :destroy], module: :cost_centers, shallow: true
    resources :letter_templates, only: [:create, :destroy], module: :cost_centers
    member do
      get :letter, to: "letters#generate"   # gera a carta (docx/pdf/preview)
      get :sheet                             # ficha do contrato em PDF
    end
    collection do
      get :report                            # relatório Excel (RELAÇÃO DE COMPROMISSOS)
      get :letter_base, to: "letters#letter_base"  # baixa o modelo-base .docx
    end
  end
  resources :receipts, only: [:index, :new]
  resources :invoices do
    resources :receipts, shallow: true, only: [:new, :create, :edit, :update, :destroy]
  end
  resources :forecast_entries
  resources :users, except: [:show]
  resources :imports, only: [:new, :create] do
    collection do
      get :template
    end
  end
  get "reports",               to: "reports#index",         as: :reports
  get "reports/monthly",       to: "reports#monthly",       as: :monthly_report
  get "reports/movement",      to: "reports#movement",      as: :movement_report

  get "audit_logs", to: "audit_logs#index"
  get "audit_logs/:id", to: "audit_logs#show", as: :audit_log

  # Administração / Manutenção (somente admin)
  get    "maintenance",          to: "maintenance#index"
  post   "maintenance/backup",   to: "maintenance#backup",   as: :maintenance_backup
  delete "maintenance/cleanup",  to: "maintenance#cleanup",  as: :maintenance_cleanup
  post   "maintenance/restore",  to: "maintenance#restore",  as: :maintenance_restore
  get    "maintenance/download", to: "maintenance#download", as: :maintenance_download

  # API de máquina — o inventário sincroniza os centros de custo daqui.
  # PRECISA vir antes do catch-all abaixo, que engole tudo o que vier depois.
  namespace :api do
    namespace :v1 do
      resources :cost_centers, only: [:index] do
        collection do
          get :deletions
        end
      end
    end
  end

  # Rota inexistente → 404 limpo (evita a página de debug do dev listando as rotas).
  match "*unmatched", to: "errors#not_found", via: :all
end
