Rails.application.routes.draw do

  root 'rooms#index'

  # unclear why the below doesn't define this
  get '/rooms/new', to: 'rooms#new'
  post '/rooms/join', to: 'rooms#join'
  get '/rooms/leave', to: 'rooms#leave'

  get '/dictionary', to: 'dictionary#index'

  resources :rooms, except: %i[edit update destroy] do
  end

  resources :chain, except: %i[edit update] do
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

  resources :ziddler, except: %i[edit update] do
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

  resources :word_lists, except: %i[create update] do
    resources :words, except: %i[show index edit update]
  end

  resources :stories, except: %i[:update] do
    post 'save', on: :member
    post 'generate', on: :member
    get 'archive', on: :collection
    get 'publish_content_job', on: :collection
  end

  resources :prompts, except: %i[show edit update] do
  end

  resources :word_mine, except: %i[edit update] do
    get "play", on: :member
    post "player", on: :member
    post "settings", on: :member
    post "start", on: :member
    post "newgame", on: :member

    post "draw", on: :member
    post "shuffle", on: :member
    post "buy", on: :member
    post "play_word", on: :member
  end

end
