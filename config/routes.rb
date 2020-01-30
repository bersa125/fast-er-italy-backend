Rails.application.routes.draw do
  root 'welcome#index'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  resources :addresses , module: 'database_req'
  resources :settings , module: 'database_req'
  resources :evaluations , module: 'database_req'
end
