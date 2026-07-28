Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#home"

  get "dashboard" => "dashboard#show", as: :dashboard

  get    "login"  => "sessions#new",     as: :login
  post   "login"  => "sessions#create"
  delete "logout" => "sessions#destroy", as: :logout
  get    "cadastro" => "registrations#new",    as: :signup
  post   "cadastro" => "registrations#create"
  get    "recuperar-senha" => "password_resets#new",    as: :new_password_reset
  post   "recuperar-senha" => "password_resets#create", as: :password_reset
  get    "recuperar-senha/editar" => "password_resets#edit",   as: :edit_password_reset
  patch  "recuperar-senha" => "password_resets#update"
  resource :password, only: [ :edit, :update ]

  namespace :admin do
    root "dashboard#index"
    resources :users, only: [ :index, :show ]
  end

  get "timeline" => "timeline#show", as: :timeline
  get "grafico"  => "chart#show",    as: :chart

  resources :race_sessions, only: [ :index, :show, :update ], path: "sessoes"

  resources :imports, only: [ :index, :new, :create, :destroy ] do
    member do
      get   :review
      patch :confirm
    end
  end

  get "pista"       => "track#show",      as: :track
  get "karts"       => "karts#index",     as: :karts
  get "comparativo" => "comparison#show", as: :comparison
  get "ranking"     => "ranking#index",    as: :ranking
  get "ranking/exportar" => "ranking#export", as: :export_ranking

  resources :profiles, param: :code, path: "contas", only: [ :index, :show, :new, :create, :edit, :update ]
end
