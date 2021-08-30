Rails.application.routes.draw do

  root 'rooms#index'

  # unclear why the below doesn't define this
  get '/rooms/new', to: 'rooms#new'
  post '/rooms/join', to: 'rooms#join'
  get '/rooms/leave', to: 'rooms#leave'

  resources :rooms, except: [:edit, :update, :destroy] do
  end

  resources :chain, except: [:edit, :update] do
    get 'play', on: :member
    post 'player', on: :member
    post 'cpu', on: :member
    post 'player_team', on: :member
    post 'settings', on: :member
    post 'start', on: :member
    post 'play_card', on: :member
    post 'rematch', on: :member
    post 'newgame', on: :member

    post 'play', on: :member
  end

  resources :ziddler, except: [:edit, :update] do
    get "play", on: :member
    post "player", on: :member
    post "settings", on: :member
    post "start", on: :member
    post "newgame", on: :member
    post "round", on: :member

    post "draw", on: :member
    post "layingdown", on: :member
    post "laydown", on: :member
    post "discard", on: :member
  end

end
