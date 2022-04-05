class WordMineController < ApplicationController

  before_action :set_game, except: [:index, :create, :delete]

  rescue_from StandardError, with: :error_handler

  skip_before_action :verify_authenticity_token

  def create
    room = params.permit('room')['room']
    puts "Creating game for room: #{room}"
    game = WordMineGame.create_fresh(room: room)
    game.save!
    redirect_to play_word_mine_path(game.id)
  end

  def index
    @games_path = word_mine_index_path
  end

  def play
    puts "Rendering SPA for play"
    @game_path = word_mine_path(@game.id)
    @root_path = root_path
    @word_lists = WordList::BONUS_WORD_LISTS
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

  def draw
    @game.draw_action(player_cookie)
    @game.save!
    render json: @game.to_h
  end

  def shuffle
    @game.shuffle_action(player_cookie)
    @game.save!
    render json: @game.to_h
  end

  def buy
    @game.buy_action(player_cookie, buy_action_params)
    @game.save!
    render json: @game.to_h
  end

  def play_word
    play_params = play_action_params
    puts play_params

    @game.play_action(player_cookie, play_params[:word], play_params[:board_card])
    @game.save!
    render json: @game.to_h
  end

  def delete
    # For some reason this does not work.  Use the class method instead
    # @game.delete
    WordMineGame.delete(params[:game_id])
    render json: {}
  end

  private

  def player_cookie
    cookies["player_#{@game.id}"]
  end

  def set_game
    @game = WordMineGame.find(id: params[:id])
  end

  def player_params
    params.require(:player)
  end

  def settings_params
    params.require(:settings).permit(:enable_bonus_words, :word_smith_bonus, :bonus_words)
  end

  def buy_action_params
    params.require(:buy).permit(:card_i, :row, :col)
  end

  def play_action_params
    params.require(:play).permit(word: [], board_card: {})
  end

  def error_handler(error)
    puts "Handling an error: #{error}"
    backtrace = error.backtrace.join("\n\t")
    puts "Backtrace:\n\t#{backtrace}"
    render json: {error: error}, status: 500
  end

end
