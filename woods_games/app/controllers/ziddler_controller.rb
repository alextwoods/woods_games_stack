class ZiddlerController < ApplicationController

  before_action :set_game, except: [:index, :create, :delete]

  rescue_from StandardError, with: :error_handler

  skip_before_action :verify_authenticity_token

  WORD_LISTS = %w[animals foods holiday]

  def create
    room = params.permit('room')['room']
    puts "Creating game for room: #{room}"
    game = ZiddlerGame.create_fresh(room: room)
    game.save!
    redirect_to play_ziddler_path(game.id)
  end

  def index
    @games_path = ziddler_index_path
  end

  def play
    puts "Rendering SPA for play"
    @game_path = ziddler_path(@game.id)
    @root_path = root_path
    @word_lists = WORD_LISTS
    @game.save! # update the updated_at time
  end

  def show
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

  # Restarts the game as a new game
  def newgame
    @game.new_game
    @game.save!
    render json: @game.to_h
  end

  # start a new round
  def round
    @game.new_round
    @game.save!
    render json: @game.to_h
  end

  def draw
    draw_type = draw_params
    @game.draw(player_cookie, draw_type)
    @game.save!
    render json: @game.to_h
  end


  def discard
    card = discard_params
    @game.discard(player_cookie, card)
    @game.save!
    render json: @game.to_h
  end

  def laydown
    laid_down = laydown_params
    laid_down[:leftover] ||= []
    @game.laydown(player_cookie, laid_down)
    @game.save!
    render json: @game.to_h
  end

  def layingdown
    laying_down = laydown_params
    @game.laying_down(player_cookie, laying_down)
    @game.save!
    render json: @game.to_h
  end

  def delete
    # For some reason this does not work.  Use the class method instead
    # @game.delete
    ZiddlerGame.delete(params[:game_id])
    render json: {}
  end

  private

  def player_cookie
    cookies["player_#{@game.id}"]
  end

  def set_game
    @game = ZiddlerGame.find(id: params[:id])
  end

  def player_params
    params.require(:player)
  end

  def settings_params
    params.require(:settings).permit(:enable_bonus_words, :word_smith_bonus, :longest_word_bonus, :most_words_bonus, :bonus_words)
  end

  def draw_params
    params.require(:draw_type)
  end

  def discard_params
    params.require(:card)
  end

  def laydown_params
    params.require(:laydown).permit!
  end

  def error_handler(error)
    puts "Handling an error: #{error}"
    backtrace = error.backtrace.join("\n\t")
    puts "Backtrace:\n\t#{backtrace}"
    render json: {error: error}, status: 500
  end

end
