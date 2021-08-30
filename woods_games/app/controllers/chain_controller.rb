class ChainController < ApplicationController

  before_action :set_game, except: [:index, :create, :delete]

  rescue_from StandardError, with: :error_handler

  # protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token

  def create
    room = params.permit('room')['room']
    puts "Creating game for room: #{room}"
    game = ChainGame.create_fresh(room: room)
    game.save!
    redirect_to play_chain_path(game.id)
  end

  def index
    @games_path = chain_index_path
  end

  # Used to render the SPA react app with various paths needed by the frontend.
  def play
    puts "Rendering SPA for play"
    @game_path = chain_path(@game.id)
    @root_path = root_path
    @game.save! # update the updated_at time
  end

  def show
    puts "Refreshing game state for: #{player_cookie}"
    render json: @game.to_h
  end

  # Add a player to the game
  # expect player=<name>
  def player
    player = player_params
    puts "Existing cookie: #{player_cookie}"
    puts "Adding player to game: #{player}"
    @game.add_player(player)

    # store player in a cookie - used for player action apis to identify the actor
    # TODO: Because we cant set http_only: false, let the front end set their own cookie
    # cookies[:player] = player
    @game.save!
    puts "Added player"
    render json: @game.to_h
  end

  # Add a CPU player to the game
  def cpu
    @game.add_cpu
    @game.save!
    puts "Added CPU"
    render json: @game.to_h
  end

  # Updates a players team
  def player_team
    player_team = player_team_params
    puts "Update team: #{player_team}"
    @game.set_player_team(player_team[:player], player_team[:team])

    @game.save!
    render json: @game.to_h
  end

  # update settings
  def settings
    puts "Got Params: #{params}"
    settings = settings_params
    puts "Updating settings to: #{settings}"
    puts "to_h=#{settings.to_h}"
    @game.update_settings(settings)

    @game.save!
    puts "Settings are now: #{@game.data['settings']}"
    render json: @game.to_h
  end

  # Starts the game
  def start
    @game.start
    @game.save!
    render json: @game.to_h
  end

  def play_card
    p = play_card_params
    puts "play_card: #{p}"
    bI = p["boardI"].to_i
    row = bI / 10
    col = bI % 10
    @game.play_card(player_cookie, p['cardI'], row, col)

    @game.save!
    if @game.next_player_cpu?
      PlayCpuJob.set(wait: @game.settings['cpu_wait_time'].to_i.seconds).perform_later(@game.id)
    end

    render json: @game.to_h
  end

  # Return to the lobby to allow adjustment of settings
  def newgame
    @game.new_game
    @game.save!
    render json: @game.to_h
  end

  # start a new game with the same settings
  def rematch
    puts "\n\n\nRematch controller...."
    @game.rematch
    @game.save!
    render json: @game.to_h
  end

  def delete
    # For some reason this does not work.  Use the class method instead
    # @game.delete
    ChainGame.delete(params[:game_id])
    render json: {}
  end

  private

  def player_cookie
    cookies["player_#{@game.id}"]
  end

  def set_game
    @game = ChainGame.find(id: params[:id])
  end

  def room_params
    params.require(:game).permit(:room)
  end

  def player_params
    params.require(:player)
  end

  def player_team_params
    params.require(:player).permit(:player, :team)
  end

  def settings_params
    params.require(:settings).permit(:board, :sequence_length, :sequences_to_win, :custom_hand_cards)
  end


  def play_card_params
    params.require(:play).permit(:cardI, :boardI)
  end

  def error_handler(error)
    puts "Handling an error: #{error}"
    backtrace = error.backtrace.join("\n\t")
    puts "Backtrace:\n\t#{backtrace}"
    render json: {error: error}, status: 500
  end

end
