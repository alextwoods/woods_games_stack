require 'set'

class WordMineGame
  include Aws::Record
  set_table_name 'woods-games-word-mine'
  string_attr :id, hash_key: true

  datetime_attr   :created_at
  datetime_attr   :updated_at

  epoch_time_attr :ttl
  string_attr :room
  map_attr :data

  TTL_30_DAYS = 3600 * 24 * 30
  TTL_2_HOURS = 3600 * 2

  # Return a list of Games who match the given room
  def self.where_room(room)
    query(
      index_name: 'room-ttl-index',
      expression_attribute_names: { "#room_id" => "room" },
      expression_attribute_values: { ":room_value" => room },
      key_condition_expression: "#room_id = :room_value",
      scan_index_forward: false # sort by most recent first
    )
  end

  # Override 'save' to set some timestamps automatically.
  def save(opts = {})
    self.created_at = Time.current unless created_at
    self.updated_at = Time.current
    self.ttl = Time.current + TTL_2_HOURS
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
  end

  def update_settings(settings)
    if data['state'] != 'WAITING_FOR_PLAYERS'
      raise "Unable to update settings for game in state: #{data[:state]}"
    end

    data['settings'] = data['settings'].merge(settings)
  end

  def start
    validate_data
    if data['state'] != 'WAITING_FOR_PLAYERS'
      raise "Unable to start game in state: #{data['state']}"
    end

    initialize_game_state
  end

  def new_game
    validate_data
    if data['state'] != 'GAME_OVER'
      raise "Unable to start a NEW game in state: #{data['state']}"
    end

    initialize_game_state
  end

  def initialize_game_state
    data['table_state'] = {}
    data['state'] = 'PLAYING'
    data['deck'] = WordMineDeck.standard_deck
    data['score'] = players.map { |p| [p, 0] }.to_h
    table_state['dealer'] = players.sample

    table_state['decks'] = decks = shuffle_decks(data['deck'])
    table_state['laid_out'] = [
      decks[0].pop(4),
      decks[1].pop(4),
      decks[2].pop(4)
    ]
    table_state['players_state'] = player_state = {}
    players.each do |player|
      player_state[player] = {}
      player_state[player]['deck'] = (decks[0].pop(5) + decks[1].pop(3) + decks[2].pop(2)).shuffle
      player_state[player]['hand'] = player_state[player]['deck'].pop(3)
      player_state[player]['discard'] = []
      player_state[player]['played'] = []
      player_state[player]['score'] = 0
      player_state[player]['actions'] = 1
    end

    table_state['active_player'] = next_player(table_state['dealer'])
    table_state['turn_state'] = 'WAITING_TO_PLAY'
    table_state['turn'] = 1
    table_state['log'] = []
    start_turn
  end

  def shuffle_decks(deck)
    common = []; medium = []; rare = [];
    deck.each_with_index { |c, i| common << i if c[2] == 0 }
    deck.each_with_index { |c, i| medium << i if c[2] == 1 }
    deck.each_with_index { |c, i| rare << i if c[2] == 2 }

    [common.shuffle, medium.shuffle, rare.shuffle]
  end

  def start_turn
    player = table_state['active_player']
    draw(player, 1)
    table_state['players_state'][player]['actions'] = 1
  end

  def draw(player, n_cards)
    validate_turn(player)
    player_state = table_state['players_state'][player]
    # draw from the deck if we have cards, otherwise shuffle the discard
    if player_state['deck'].size > 0
      player_state['hand'] += player_state['deck'].pop(1)
    elsif player_state['discard'].size > 0
      # shuffle the discard into the deck
      table_state['log'] << {type: 'DRAW_SHUFFLE', player: player, time: Time.current.to_i, turn: turn, message: 'Shuffling the discard into the deck'}
      player_state['deck'] = player_state['discard'].pop(player_state['discard'].size).shuffle
      player_state['hand'] += player_state['deck'].pop(1)
    else
      table_state['log'] << {type: 'INFO', player: player, time: Time.current.to_i, turn: turn, message: 'Not enough cards to draw from.'}
      puts "WARNING: Insufficent cards to draw from.  Skipping."
    end

    draw(player, n_cards-1) if n_cards > 1
  end

  def draw_action(player)
    validate_turn(player)
    player_state = table_state['players_state'][player]
    if player_state['actions'] <= 0
      raise ArgumentError, 'No remaining actions.'
    end

    draw(player, 2)
    player_state['actions'] -= 1
    table_state['log'] << {type: 'ACTION_DRAW', player: player, time: Time.current.to_i, turn: turn, message: 'Drew 2 cards from their deck'}

    check_end_of_turn(player)
  end

  def check_end_of_turn(player)
    player_state = table_state['players_state'][player]
    if player_state['actions'] <= 0
      next_turn(player)
    end
  end

  # we need to know what cards and what order
  # ONE of the cards will be from the board (row, col)
  # the rest are from the hand.
  # word: list of cardI
  # board_card: {:card_i, :row, :col} (the cardI should also be in the word)
  def play_action(player, word, board_card)
    board_card = board_card.to_h.transform_values { |v| v.to_i }
    word = word.map { |v| v.to_i }
    player_state = table_state['players_state'][player]
    player_state['hand'] = player_state['hand'].map { |v| v.to_i }

    # validations
    validate_turn(player)
    if player_state['actions'] <= 0
      raise ArgumentError, 'No remaining actions.'
    end

    if table_state['laid_out'][board_card['row']][board_card['col']]&.to_i != board_card['card_i']
      raise ArgumentError, 'Invalid play: Board cardI does not match'
    end

    if (word - player_state['hand'] != [board_card['card_i']])
      raise ArgumentError, 'Invalid play: word cards dont match hand.'
    end

    # place all of the word cards into players discard
    player_state['discard'] += word
    # remove word cards from hand
    player_state['hand'] = player_state['hand'] - word
    # replace the board card
    table_state['laid_out'][board_card['row']][board_card['col']] = table_state['decks'][board_card['row']].pop

    player_state['actions'] -= 1

    word_letters = ""
    points = 0
    word.each do |c_i|
      deck_card = data['deck'][c_i]
      points += deck_card[1].to_i
      word_letters << deck_card[0]
    end
    player_state['played'] << { word: word_letters, cards: word, score: points, board_card: board_card }
    player_state['score'] = player_state['score'].to_i + points

    table_state['log'] << {type: 'ACTION_BUILD_WORD',
                           time: Time.current.to_i, player: player, turn: turn,
                           word_cards: word, score: points, word: word_letters,
                           board_card: board_card,
                           message: "Played #{word_letters} for #{points} points - used #{data['deck'][board_card['card_i']][0]} from the board"}


    check_end_of_turn(player)
  end

  # buys a card from the board
  # board_card: {:card_i, :row, :col}
  def buy_action(player, board_card)
    board_card = board_card.to_h.transform_values { |v| v.to_i }
    player_state = table_state['players_state'][player]

    # validations
    validate_turn(player)
    if player_state['actions'] <= 0
      raise ArgumentError, 'No remaining actions.'
    end

    if table_state['laid_out'][board_card['row']][board_card['col']]&.to_i != board_card['card_i']
      raise ArgumentError, 'Invalid buy: Board cardI does not match'
    end

    card_cost = data['deck'][board_card['card_i']][1].to_i
    if card_cost > player_state['score'].to_i
      raise ArgumentError, 'Invalid buy: Insufficent score to buy the card.'
    end

    player_state['score'] = player_state['score'].to_i - card_cost

    # add new card to hand
    player_state['hand'] << board_card['card_i']
    # replace the board card
    table_state['laid_out'][board_card['row']][board_card['col']] = table_state['decks'][board_card['row']].pop

    player_state['actions'] -= 1
    check_end_of_turn(player)
  end

  def shuffle_action(player)
    player_state = table_state['players_state'][player]

    # validations
    validate_turn(player)
    if player_state['actions'] <= 0
      raise ArgumentError, 'No remaining actions.'
    end

    player_state['deck'] = (player_state['deck'] + player_state['discard']).shuffle
    player_state['discard'] = []
    player_state['actions'] -= 1
    table_state['log'] << {type: 'ACTION_SHUFFLE', time: Time.current.to_i, player: player, turn: turn, message: 'Shuffled discard into their deck.'}

    check_end_of_turn(player)
  end

  def turn
    table_state['turn'].to_i
  end

  def next_turn(player)
    np = next_player(player)

    # TODO: Check for end of game
    if player == table_state['dealer']
      table_state['turn'] = table_state['turn'].to_i + 1
    end
    table_state['active_player'] = np
    table_state['turn_state'] = 'WAITING_TO_PLAY'
    start_turn
  end

  def table_state
    data['table_state']
  end

  def players
    data['players']
  end

  # map of player to index
  def p_i(player)
    players.find_index(player)
  end

  def next_player(player)
    players[(p_i(player) + 1) % players.size]
  end

  def hand(player)
    table_state['hands'][player].map {|cI| cI.to_i }
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
      raise ArgumentError, "Cannot take turn.  Player #{player} is not the active_player: #{table_state['active_player']}"
    end
  end

  def end_round
    table_state['turn_state'] = 'ROUND_COMPLETE'
    data['state'] = 'WAITING_FOR_NEXT_ROUND'
    if data['round'].to_i >= 7
      data['state'] = 'GAME_OVER'
    end

    # compute longest word and most word bonuses (2+ players only)
    longest_words = longest_words(table_state["laid_down"])
    if players.size >= 2 && data['settings'] && data['settings']['longest_word_bonus']
      puts "Computed longest_words: #{longest_words}"
      if (longest_words[0][1] > longest_words[1][1])
        player = longest_words[0][0]
        puts "Longest Word: #{player}"
        table_state["laid_down"][player]['longest_word_bonus'] = 10
        table_state['laid_down'][player]['score'] += 10
      end
    end

    # compute 7+ letter bonus
    if data['settings'] && data['settings']['word_smith_bonus']
      longest_words.each do |player, size|
        if size >= 7
          table_state["laid_down"][player]['word_smith_bonus'] = 10
          table_state['laid_down'][player]['score'] += 10
        end
      end
    end

    if players.size >= 2 && data['settings'] && data['settings']['most_words_bonus']
      n_words = table_state["laid_down"].map {|p,x| [p, x['words'].size] }.sort_by { |x| x[1] }.reverse!
      if (n_words[0][1] > n_words[1][1])
        player = n_words[0][0]
        table_state["laid_down"][player]['most_words_bonus'] = 10
        table_state['laid_down'][player]['score'] += 10
      end
    end

    # compute word list bonuses (if in settings)
    if data['settings'] &&
      data['settings']['enable_bonus_words'] &&
      (wl_name = data['settings']['bonus_words'])
      table_state["laid_down"].each do |player, x|
        words = x['words'].map { |w| w['word'] }.select { |w| !Word.find(id: wl_name, word: w.downcase).nil? }
        if words.length > 0
          puts "PLAYER BONUS! #{player} : #{words.join(', ')}"
          bw_score = 10 * words.size
          table_state["laid_down"][player]['bonus_words_score'] = bw_score
          table_state['laid_down'][player]['score'] += 10
          table_state["laid_down"][player]['bonus_words'] = words.join(', ')
        end
      end
    end

    data['round_summaries'] << table_state['laid_down']
    compute_card_counts
    compute_stats
    add_definitions

    players.each do |player|
      data['score'][player] = data['score'][player].to_i + table_state['laid_down'][player]['score'].to_i
    end
  end

  # compute stats from round summaries
  def compute_stats
    rounds = data['round_summaries']
    stats = {}

    # list of best (highest score) words by player
    # goal: flat map to [player, word, score]
    best_words = rounds.each_with_index.map { |summary, round_i| summary.map { |p, x| x['words'].map { |w| [p, w['word'], w['points'].to_i, round_i] }}}.flatten(2).sort_by { |x| x[2] }.reverse
    stats['best_words'] = best_words

    longest_words = rounds.each_with_index.map { |summary, round_i| summary.map { |p, x| x['words'].map { |w| [p, w['word'], w['word'].length, round_i] }}}.flatten(2).sort_by { |x| x[2] }.reverse
    stats['longest_words'] = longest_words

    n_words = {}
    rounds.each { |summary| summary.each { |p, x| n_words[p] = n_words.fetch(p, 0) + x['words'].length } }
    n_words = n_words.to_a.sort_by { |x| x[1] }.reverse
    stats['n_words'] = n_words

    leftovers = {}
    rounds.each { |summary| summary.each { |p, x| leftovers[p] = leftovers.fetch(p, 0) + x['leftover'].length } }
    leftovers = leftovers.to_a.sort_by { |x| x[1] }
    stats['leftover_letters'] = leftovers

    data['stats'] = stats
  end

  def compute_card_counts
    data['card_counts'] ||= {}
    cards = table_state['discard']
    cards += table_state["laid_down"].map { |p, l| l["cards"].flatten + l["leftover"] }.flatten
    cards = cards.map { |c| data['deck'][c.to_i][0]}
    cards.each do |c|
      data['card_counts'][c] = data['card_counts'].fetch(c, 0) + 1
    end

    data['card_ev'] = {}
    deck_counts = data["deck"].map { |c| c[0] }.tally
    n_deck_cards = deck_counts.values.sum
    cards_played = data['card_counts'].values.sum
    deck_counts.each do |c, i|
      data['card_ev'][c] = {
        p: i.to_f / n_deck_cards.to_f,
        ev: i.to_f / n_deck_cards.to_f * cards_played,
        actual: data['card_counts'].fetch(c, 0)
      }
    end
  end

  def add_definitions
    table_state['definitions'] = {}

    words = table_state["laid_down"].map { |p, l| l['words'].map { |w| w['word'] } }.flatten
    words.each do |word|
      table_state['definitions'][word] = Dictionary.find(word: word.upcase)&.def
    end
  end

  def self.create_fresh(room: nil)
    game = WordMineGame.new
    game.id = SecureRandom.uuid
    game.room = room || 'NO_ROOM'
    game.ttl = Time.now.to_i + TTL_2_HOURS
    game.data = {
      'players' => [],
      'state' => 'WAITING_FOR_PLAYERS',
      'table_state' => {},
      'settings' => {
        'enable_bonus_words' => true,
        'bonus_words' => 'animals',
        'longest_word_bonus' => true,
        'most_words_bonus' => false,
        'word_smith_bonus' => true
      }
    }
    game
  end
end

def longest_words(laid_down)
  laid_down.map(&method(:player_longest_word)).sort_by { |x| x[1] }.reverse
end

def player_longest_word(p,x)
  puts "Computing player longest word: #{p}, #{x}"
  [p, longest_word(x['words'])]
end

def longest_word(words)
  words.map{ |y| y['word']&.size || 0 }.max || 0
end
