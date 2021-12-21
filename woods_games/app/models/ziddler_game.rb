require 'set'

class ZiddlerGame
  include Aws::Record
  set_table_name 'woods-games-ziddler'
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

    self.ttl = Time.now.to_i + TTL_30_DAYS

    data['state'] = 'PLAYING'
    data['deck'] = ZiddlerDeck.standard_deck
    data['score'] = players.map { |p| [p, 0] }.to_h
    table_state['dealer'] = players.first
    start_round(data['round'])
  end

  def new_game
    validate_data
    if data['state'] != 'GAME_OVER'
      raise "Unable to start a NEW game in state: #{data['state']}"
    end

    data['round'] = 0
    data['table_state'] = {}
    data['round_summaries'] = []
    data['state'] = 'PLAYING'
    data['deck'] = ZiddlerDeck.standard_deck
    data['score'] = players.map { |p| [p, 0] }.to_h
    table_state['dealer'] = players.first
    start_round(data['round'])
  end

  def new_round
    data['round'] = data['round'].to_i + 1
    data['state'] = 'PLAYING'
    start_round(data['round'])
  end

  def start_round(round)
    # determine new dealer
    table_state['dealer'] = next_player(table_state['dealer'])
    table_state['deck'] = deck = (0...data['deck'].size).to_a.shuffle
    table_state['hands'] = hands = {}
    players.each do |player|
      hands[player] = deck.pop(round + 3)
    end
    table_state['discard'] = [deck.pop, deck.pop]

    table_state['laid_down'] = {}
    table_state['laying_down'] = nil

    table_state['active_player'] = next_player(table_state['dealer'])
    table_state['turn_state'] = 'WAITING_TO_DRAW'
    table_state['turn'] = 1
  end

  # draw_type can be DECK, DISCARD
  def draw(player, draw_type)
    validate_turn(player)
    unless table_state['turn_state'] == 'WAITING_TO_DRAW'
      raise "Cannot draw, turn state: #{table_state['turn_state']}"
    end

    case draw_type
    when 'DECK'
      card = table_state['deck'].pop
    when 'DISCARD'
      card = table_state['discard'].pop
    else
      raise 'Invalid draw_type'
    end

    table_state['hands'][player] << card
    table_state['turn_state'] = 'WAITING_TO_DISCARD'
  end

  # draw_type can be DECK, DISCARD
  def discard(player, card)
    validate_turn(player)
    unless table_state['turn_state'] == 'WAITING_TO_DISCARD'
      raise "Cannot discard, turn state: #{table_state['turn_state']}"
    end

    unless table_state['laid_down'].blank?
      raise "Last turn - must lay down"
    end

    hand_i = hand(player).find_index(card.to_i)
    if hand_i.nil?
      raise "Cannot discard card: #{card} from hand: #{hand(player)}"
    end

    table_state['hands'][player].delete_at(hand_i)
    table_state['discard'] << card

    if players.size == 1
      # put a random card on the discard
      table_state['discard'] << table_state['deck'].pop
    end

    next_turn(player)
  end

  #laid_down:
  #     {
  #       words: [ [cid, cid], [cid] ]
  #       leftover: [ cids ]
  #       discard: cid  #required single card
  #     }
  def laydown(player, laid_down)
    validate_turn(player)
    unless table_state['turn_state'] == 'WAITING_TO_DISCARD'
      raise "Cannot laydown, turn state: #{table_state['turn_state']}"
    end

    # remove zero card words
    word_cards = laid_down[:words].to_h.values.select{ |w| w && w.length > 0 }

    # TODO: validate all cards played were in the hand
    words = word_cards.map do |cards|
      points = 0
      word = ""
      cards.each do |card|
        deck_card = data['deck'][card.to_i]
        points += deck_card[1].to_i
        word << deck_card[0]
      end
      {'word' => word, 'points' => points}
    end
    word_score = words.map { |w| w['points'] }.sum
    leftover = laid_down[:leftover].to_a || []
    leftover_score = leftover.map { |c| data['deck'][c.to_i][1].to_i }.sum
    score = [word_score - leftover_score, 0].max

    table_state['laid_down'][player] = {
      'cards' => word_cards,
      'words' => words,
      'leftover' => leftover,
      'score' => [score, 0].max
    }

    table_state['hands'][player] = []
    table_state['discard'] << laid_down[:discard]

    next_turn(player)
  end

  def laying_down(player, laid_down)
    validate_turn(player)
    unless table_state['turn_state'] == 'WAITING_TO_DISCARD'
      raise "Cannot laydown, turn state: #{table_state['turn_state']}"
    end

    if laid_down['words'].blank?
      table_state['laying_down'] = nil
      return
    end

    # remove zero card words
    words = laid_down['words'].to_h.values.select{ |w| w && w.length > 0 }

    # TODO: validate all cards played were in the hand
    words = words.map do |cards|
      points = 0
      word = ""
      cards.each do |card|
        card = card.to_i
        points += data['deck'][card][1].to_i
        word << data['deck'][card][0]
      end
      {word: word, points: points}
    end
    word_score = words.map { |w| w[:points] }.sum
    leftover = laid_down[:leftover].to_a || []
    leftover_score = leftover.map { |c| data['deck'][c.to_i][1].to_i }.sum
    score = [word_score - leftover_score, 0].max

    table_state['laying_down'] = {
      'cards' => laid_down[:words].to_h.map { |_k, v| v },
      'words' => words,
      'leftover' => leftover,
      'score' => score
    }
  end

  def next_turn(player)
    np = next_player(player)
    table_state['laying_down'] = nil
    if table_state["laid_down"].include? np
      # end of the round - this player has already laid down
      end_round
    else
      if player == table_state['dealer']
        table_state['turn'] = table_state['turn'].to_i + 1
      end
      table_state['active_player'] = np
      table_state['turn_state'] = 'WAITING_TO_DRAW'
    end
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
      raise "Cannot take turn.  Player #{player} is not the active_player: #{table_state['active_player']}"
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

  def self.create_fresh(room: nil)
    game = ZiddlerGame.new
    game.id = SecureRandom.uuid
    game.room = room || 'NO_ROOM'
    game.ttl = Time.now.to_i + TTL_2_HOURS
    game.data = {
      'players' => [],
      'state' => 'WAITING_FOR_PLAYERS',
      'round' => 0,
      'table_state' => {},
      'round_summaries' => [],
      'card_counts' => {},
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
