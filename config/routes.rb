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

  resources :cost_centers
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
  get "audit_logs", to: "audit_logs#index"
  get "audit_logs/:id", to: "audit_logs#show", as: :audit_log
end
