Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root "cryptocurrencies#index"
  
  # ActionCable WebSocket mount
  mount ActionCable.server => '/cable'
  
  # Database viewer route (nur in Development)
  if Rails.env.development?
    get '/database', to: 'database#index'
    post '/database/execute', to: 'database#execute', as: :execute_database
    get '/database/table/:table', to: 'database#table', as: :database_table
    # Sidekiq Web Interface
    # require 'sidekiq/web'
    # mount Sidekiq::Web => '/sidekiq'
  end
  
  resources :cryptocurrencies, only: [:index, :show] do
    collection do
      # post :refresh_data
      # post :update_roc
      get :settings
      patch :update_settings
      get :add_roc_derivative
      post :add_roc_derivative
      get :averages_chart
      get :last_update
      post :calculate_rsi
      post :update_rsi_settings
    end
    member do
      get :chart
      get :chart_data
    end
  end

  resources :balances, only: [:index] do
    collection do
      get :chart_data
    end
  end

  # Health check endpoint for production monitoring
  get '/health', to: proc { [200, {'Content-Type' => 'text/plain'}, ['OK']] }
  
  # API routes
  namespace :api do
    namespace :v1 do
      resources :cryptocurrencies, only: [:index, :show] do
        member do
          get :chart_data
        end
      end
    end
  end
  
  # Test-Routes
  get '/test', to: 'test#index'
  post '/test/rsi', to: 'test#rsi'
  post '/test/price', to: 'test#price'
  post '/test/counter', to: 'test#counter'
  get '/test/start_simulator', to: 'test#start_simulator'
  get '/test/start_websocket_service', to: 'test#start_websocket_service'
  
  # WebSocket-Zähler Route
  post '/websocket_counters/send', to: 'websocket_counters#send_counters'
end 