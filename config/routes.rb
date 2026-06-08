Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "users/sessions" }

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
    resources :adjustments, only: [:create], module: :cost_centers
    collection do
      get :report   # relatório Excel (RELAÇÃO DE COMPROMISSOS)
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
  get "reports/monthly", to: "reports#monthly", as: :monthly_report

  get "audit_logs", to: "audit_logs#index"
  get "audit_logs/:id", to: "audit_logs#show", as: :audit_log

  # Administração / Manutenção (somente admin)
  get    "maintenance",          to: "maintenance#index"
  post   "maintenance/backup",   to: "maintenance#backup",   as: :maintenance_backup
  delete "maintenance/cleanup",  to: "maintenance#cleanup",  as: :maintenance_cleanup
  post   "maintenance/restore",  to: "maintenance#restore",  as: :maintenance_restore
  get    "maintenance/download", to: "maintenance#download", as: :maintenance_download
end
