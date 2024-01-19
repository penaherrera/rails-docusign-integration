Rails.application.routes.draw do
  resources :users do
    get 'request_signature', on: :member
  end

  root to: 'users#new'
  # get 'users/request_signature', to: 'users#request_signature'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
