require 'set'

class ChainGame
  include Aws::Record
  set_table_name 'woods-games-chain'
  string_attr :id, hash_key: true

  datetime_attr   :created_at
  datetime_attr   :updated_at

  epoch_time_attr :ttl
  string_attr :room
  map_attr :data

  #   nplayers  2  3  4  5  6  7  8  9  10 11 12
  HAND_CARDS = [7, 6, 6, 6, 5, 5, 4, 4, 3, 3, 3]

  TTL_30_DAYS = 3600 * 24 * 30
  TTL_30_MINUTES = 60 * 30

  CPU_NAMES = %w[bender data chip hal marvin cloud hal bin nibble]

  # Return a list of Games who match the given room
  def self.where_room(room)
    query(
      index_name: 'room-ttl-index',
      expression_attribute_names: { "#room_id" => "room" },
      expression_attribute_values: { ":room_value" => room },
      key_condition_expression: "#room_id = :room_value",
      scan_index_forward: false, # sort by most recent first
      )
  end

  # Override 'save' to set some timestamps automatically.
  def save(opts = {})
    self.created_at = Time.current unless created_at
    self.updated_at = Time.current
    self.ttl = Time.current
    super opts
  end

  def add_player(player)
    validate_data
    if data['state'] != 'WAITING_FOR_PLAYERS'
      raise "Unable to add player to game in state: #{data[:state]}"
    end

    if data['players'].include? player
      raise "Unable to add duplicate player.  #{player} is already in the game"
    end

    data['players'] << player
    # assign a team to the player - pick the shortest
    green_len = data['teams']['green']['players'].size
    blue_len = data['teams']['blue']['players'].size
    if blue_len < green_len
      set_player_team(player, 'blue')
    else
      set_player_team(player, 'green')
    end
  end

  def add_cpu
    name = (CPU_NAMES - players).sample
    add_player(name)
    data["cpu_players"] << name
  end

  def set_player_team(player, team)
    # check if the player is in a team already, if so remove them first
    if (previous_team = player_team[player])
      data["teams"][previous_team]["players"] = data["teams"][previous_team]["players"].select { |p| p != player }
    end
    player_team[player] = team
    data["teams"][team]["players"] << player
  end

  def update_settings(settings)
    if data['state'] != 'WAITING_FOR_PLAYERS'
      raise "Unable to update settings for game in state: #{data[:state]}"
    end

    settings['sequences_to_win'] = settings['sequences_to_win'].to_i if settings['sequences_to_win']
    settings['sequence_length'] = settings['sequence_length'].to_i if settings['sequence_length']
    data['settings'] = data['settings'].merge(settings)

    puts "Updated settings: #{settings}"
  end

  def start
    validate_data
    if data['state'] != 'WAITING_FOR_PLAYERS'
      raise "Unable to start game in state: #{data['state']}"
    end

    self.ttl = Time.now.to_i + TTL_30_DAYS

    data['state'] = 'WAITING_TO_PLAY'
    data['table_state'] = {}

    table_state['n_hand_cards'] = settings['custom_hand_cards'].blank?  ? HAND_CARDS[[0, players.size-2].max] : settings['custom_hand_cards']
    table_state['deck'] = deck = (0...ChainDeck.size).to_a.shuffle

    table_state['hands'] = hands = {}
    players.each do |player|
      hands[player] = deck.pop(table_state['n_hand_cards'])
    end
    table_state['discard'] = []

    set_board(ChainBoard.send("build_#{settings['board']}"))

    # interleve all of the team arrays to ensure we alternate teams
    # TODO: settings for alternate play orders
    table_state['player_order'] = teams['blue']['players'].zip(teams['green']['players'], teams['red']['players']).zip.flatten.compact
    table_state['active_player'] = table_state['player_order'].sample
    table_state['state'] = 'WAITING_TO_PLAY'
    table_state['turn'] = 0
    table_state['log'] = []

    # if a cpu player is the first player, have them play
    play_cpu
  end

  def new_game
    validate_data
    if data['state'] != 'GAME_OVER'
      raise "Unable to start a NEW game in state: #{data['state']}"
    end

    data['state'] = 'WAITING_FOR_PLAYERS'
    data['table_state'] = {}
    data['turn'] = 0
  end

  def rematch
    validate_data
    if table_state['state'] != 'GAME_OVER'
      raise "Unable to start a NEW game in state: #{data['state']}"
    end

    data['state'] = 'WAITING_TO_PLAY'
    data['table_state'] = {}

    table_state['n_hand_cards'] = settings['custom_hand_cards'].blank?  ? HAND_CARDS[[0, players.size-2].max] : settings['custom_hand_cards']
    table_state['deck'] = deck = (0...ChainDeck.size).to_a.shuffle

    table_state['hands'] = hands = {}
    players.each do |player|
      hands[player] = deck.pop(table_state['n_hand_cards'])
    end
    table_state['discard'] = []

    set_board(ChainBoard.send("build_#{settings['board']}"))

    # interleve all of the team arrays to ensure we alternate teams
    # TODO: settings for alternate play orders
    table_state['player_order'] = teams['blue']['players'].zip(teams['green']['players'], teams['red']['players']).zip.flatten.compact
    table_state['active_player'] = table_state['player_order'].sample
    table_state['state'] = 'WAITING_TO_PLAY'
    table_state['turn'] = 0
    table_state['log'] = []

    # if a cpu player is the first player, have them play
    play_cpu
  end

  # play up to max_turns of CPU players
  # Returns instantly if active player is not a CPU
  def play_cpu(max_turns=nil)
    validate_data
    if data['state'] != 'WAITING_TO_PLAY'
      return # if the game has been won, just return
      # raise ArgumentError, "Invalid game state: #{data['state']}"
    end
    max_turns ||= data["cpu_players"].size
    t = 0
    while t < max_turns && next_player_cpu?
      _play_cpu
      t += 1
    end
  end

  # internal method.  Active player MUST already be a cpu
  # plays one round for the cpu
  # gets the score for every possible (non jack) play for the cpu,
  # picks the best and plays
  def _play_cpu
    scores = []
    board = get_board
    cpu = active_player
    team = player_team[cpu]
    hand = hand(cpu)
    hand.each_with_index do |cI, hI|
      # skip jacks... for now
      # TODO: Handle jacks
      c = ChainDeck.card(cI)
      next if c[:number] == 11
      board.board_loc(c).each do |p_bI|
        if board.tokens[p_bI].nil?
          r, c = board.bI_to_rc(p_bI)
          # offensive
          scores << {hI: hI, cI: cI, bI: p_bI, row: r, col: c, score: board.score_move(r, c, team, settings['sequence_length'])}

          # defensive - for each other team, capture the value of the score IF the card was played for them
          other_teams = data["teams"]
        end
      end
    end
    play = (scores.sort_by { |s| s[:score] }).last
    play_card(cpu, play[:cI], play[:row], play[:col])
  end

  def play_card(player, cardI, row, col)
    validate_turn(player)

    cardI = cardI.to_i
    row = row.to_i
    col = col.to_i

    hand_i = hand(player).find_index(cardI)
    if hand_i.nil?
      raise "Cannot play card: #{card} from hand: #{hand(player)}"
    end

    team = player_team[player]

    board = get_board
    log_entry = board.play(cardI, row, col, team)
    if ChainDeck.anti_wild?(ChainDeck.card(cardI))
      new_sequences = []
    else
      new_sequences = board.new_sequences_at(row, col, team, settings['sequence_length']) # this also updates the board
    end
    puts "NEW SEQUENCE: #{new_sequences}" if new_sequences.size > 0

    table_state['hands'][player].delete_at(hand_i)
    table_state['discard'] << cardI
    table_state['hands'][player] << table_state['deck'].pop

    log_entry['player'] = player
    log_entry['new_sequences'] = new_sequences if new_sequences.size > 0
    table_state['log'] << log_entry
    next_turn(player)
  end

  # # @overide
  # # ensure that the @board gets properly serialized
  # def replace
  #   if @board
  #     table_state['board'] = @board.to_h
  #   end
  #
  #   super
  # end


  def next_turn(player)
    # check for wins
    get_board.sequences.each_pair do |team, sequences|
      if sequences.size >= settings['sequences_to_win'].to_i
        table_state['state'] = 'GAME_OVER'
        data['state'] = 'GAME_OVER'

        table_state['winner'] = team
      end
    end

    #check for draw state
    if get_board.tokens.select { |t| t.nil? }.size <= 4
      table_state['state'] = 'GAME_OVER'
      data['state'] = 'GAME_OVER'

      table_state['winner'] = 'NONE'
    end

    return unless table_state['state'] == 'WAITING_TO_PLAY'

    np = next_player(player)
    table_state['turn'] = table_state['turn'].to_i + 1
    table_state['active_player'] = np
  end

  def table_state
    data['table_state']
  end

  def players
    data['players']
  end

  def player_team
    data['player_team']
  end

  def teams
    data['teams']
  end

  def settings
    data['settings']
  end

  def player_order
    table_state['player_order']
  end

  # map of player to index
  def p_i(player)
    player_order.find_index(player)
  end

  def next_player(player)
    player_order[(p_i(player) + 1) % player_order.size]
  end

  def hand(player)
    table_state['hands'][player].map {|cI| cI.to_i }
  end

  def active_player
    table_state['active_player']
  end

  def set_board(board)
    @board = board
    table_state['board'] = board.to_h
  end

  def get_board
    @board ||= ChainBoard.from_h(table_state['board'])
  end

  def next_player_cpu?
    table_state['state'] == 'WAITING_TO_PLAY' && data["cpu_players"].include?(active_player)
  end

  private

  # raise an exception if data is missing key fields
  def validate_data
    if data.blank? || data['players'].nil? || data['state'].nil? || data['table_state'].nil?
      raise "Invalid game data state: #{data}"
    end
  end

  def validate_turn(player)
    validate_data
    unless table_state['active_player'] == player
      raise "Cannot take turn.  Player #{player} is not the active_player: #{table_state['active_player']}"
    end
  end

  def self.create_fresh(room: nil)
    game = ChainGame.new
    game.id = SecureRandom.uuid
    game.room = room || 'NO_ROOM'
    game.ttl = Time.now + TTL_30_MINUTES
    game.data = {
      'players' => [],
      'teams' => {
        'green' => {'color' => '0x00ff00', 'players' => []},
        'blue' => {'color' => '0x0000ff', 'players' => []},
        'red' => {'color' => '0xff0000', 'players' => []}
      },
      "player_team" => {

      },
      "cpu_players" => [],
      'state' => 'WAITING_FOR_PLAYERS',
      'turn' => 0,
      'table_state' => {},
      'settings' => {
        'sequences_to_win' => 2,
        'sequence_length' => 5,
        'board' => 'spiral',
        'custom_hand_cards' => nil,
        'cpu_wait_time' => Rails.env.production? ? 2.0 : nil # ENV_REMOTE is defined in .env.development.remote
      }
    }
    game
  end
end

