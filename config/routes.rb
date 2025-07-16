Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root "cryptocurrencies#index"
  
  resources :cryptocurrencies, only: [:index, :show] do
    collection do
      post :refresh_data
      post :update_roc
      get :settings
      patch :update_settings
    end
    member do
      get :chart
      get :chart_data
    end
  end

  resources :balances, only: [:index] do
    collection do
      get :chart_data
      post :refresh_data
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
end 