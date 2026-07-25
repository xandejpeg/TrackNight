Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#show"

  get    "login"  => "sessions#new",     as: :login
  post   "login"  => "sessions#create"
  delete "logout" => "sessions#destroy", as: :logout
  resource :password, only: [ :edit, :update ]

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
