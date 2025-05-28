Rails.application.routes.draw do
  root 'cryptocurrencies#index'
  
  resources :cryptocurrencies, only: [:index, :show] do
    collection do
      post :refresh_data
    end
    member do
      get :chart
    end
  end
  
  # API routes
  namespace :api do
    namespace :v1 do
      resources :cryptocurrencies, only: [:index, :show]
    end
  end
end 