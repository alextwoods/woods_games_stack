
class ChainBoard

  # Board should be a 1 dim array of Cards (12H or F), treated as a 2 dim board
  # tokens: 1 dim array of Teams, same size as board.  Nil for empty/no token at that location
  # sequences: map of team to array of boardI that make up the sequence
  def initialize(board, tokens=nil, sequences={})
    @board = board
    @size = Math.sqrt(board.size).to_i
    raise ArgumentError, 'Only 10x10 boards currently supported' unless @size == 10

    @tokens = tokens || Array.new(@board.size)
    @card_map = Hash.new { [] }
    @board.each_with_index do |b, i|
      @card_map[b] = @card_map.fetch(b, []) << i
    end
    @sequences = sequences
  end

  attr_reader :board, :size, :tokens

  attr_accessor :sequences

  def to_s
    rows = []
    # merge in the played tokens to be printed "ontop" of the spaces
    bt = @board.dup
    all_seq = Set.new(@sequences.values.flatten.compact)
    @tokens.each_with_index do |t, i|
      unless t.nil?
        bt[i] = all_seq.include?(i) ? "X#{t[0].upcase}X" : "_#{t[0].upcase}_"
      end
    end

    (0...@size).each do |j|
      rows << bt[j*@size, @size].join("\t")
    end
    rows.join("\n")
  end

  def [](i,j)
    @board[i*@size + j]
  end

  def bI_to_rc(bI)
    [bI / @size, bI % @size]
  end

  def token_at(i, j)
    @tokens[i*@size + j]
  end

  # WARNING: This does not update the sequences with the play, this should only be used internally and for testing
  def set_token(i, j, team)
    @tokens[i*@size + j] = team
  end

  def board_loc(card)
    @card_map["#{card[:number]}#{card[:suit]}"]
  end

  def play(cardI, row, column, team)
    card = ChainDeck.card(cardI)
    raise "Invalid play for #{team} at #{row},#{column} of card: #{cardI}" unless valid_play?(card, row, column, team)
    if ChainDeck.anti_wild? card
      removed = token_at(row, column)
      set_token(row, column, nil) # remove the token
      {cardI: cardI, row: row, col: column, team: team, removed: removed}
    else
      set_token(row, column, team)
      {cardI: cardI, row: row, col: column, team: team}
    end

  end

  def part_of_sequence?(row, column)
    boardI = (row * 10) + column
    team = token_at(row, column)
    return false unless team
    team_sequences = @sequences.fetch(team, [])
    team_sequences.flatten.include?(boardI)
  end

  def valid_play?(card, row, column, team)
    if ChainDeck.wild?(card)
      # not a free space and theres nothing there yet
      return self[row, column] != 'F' && token_at(row, column).nil?
    elsif ChainDeck.anti_wild?(card)
      # not a free space and theres a token from another team
      # AND the token is not part of a sequence
      token = token_at(row, column)
      return self[row, column] != 'F' && token && token != team && !part_of_sequence?(row, column)
    else
      card_s = "#{card[:number]}#{card[:suit]}"
      # card matches and theres nothing there yet
      return card_s == self[row, column] && token_at(row, column).nil?
    end
  end

  # CPU players to check the value of a move
  def score_move(row, column, team, sequence_length=5)
    score = 0

    dirs = %i[horizontal vertical d1 d2]
    dirs.each do |dir|
      s, _ = sequence_in_dir(row, column, team, dir, sequence_length)
      score += score_dir(s, sequence_length)
    end
    score
  end

  def score_dir(s, sequence_length)
    return 0 if s.size < sequence_length
    n_empty = s.select(&:nil?).size
    n_tokens = s.size - n_empty
    to_seq = [sequence_length - n_tokens, 0.0001].max # prevent negative, prevent blow up of div by zero
    sequence_length / (to_seq ** 1.8)
  end

  # this method is used to check for sequences (including all possible incomplete but achievable sequences)
  # Update the @sequences with any new sequence.
  # in order to capture a sequence and store it, we need the boardI.
  def new_sequences_at(row, column, team, sequence_length=5)
    new_sequences = []

    dirs = %i[horizontal vertical d1 d2]
    dirs.each do |dir|
      s, bi = sequence_in_dir(row, column, team, dir, sequence_length)
      if (s_new = check_new_sequence(s, bi, team, sequence_length))
        new_sequences << s_new
      end
    end
    team_sequences = @sequences.fetch(team, [])
    # validate sequences do not overlap too much
    # HACK: its possible to use too many tokens from a previous sequence
    new_sequences = new_sequences.filter do |new|
      f = team_sequences.none? { |existing| (existing & new).size > 1 }
      if f
        puts "WARNING: got a bad sequenece. filtering it out: #{new}"
        puts "Existing: #{team_sequences}"
      end
      f
    end
    team_sequences += new_sequences
    @sequences[team] = team_sequences.compact

    new_sequences
  end

  # given output from sequence_in_dir, check for an actual completed sequence
  # WARNING: this method currently modifies its arguments
  # @return boardI for the NEW sequence.  Nil if no new sequence
  def check_new_sequence(tokens, boardI, team, sequence_length)
    # [ O O O E E ]
    # [ E E O O O ]
    # Crazy new idea: BEFORE processing, go in and replace team with "X" for existing sequences.
    # then walk from left to right, looking for max sequence of Team.
    team_sequences = @sequences.fetch(team, [ [] ])

    # if any sequence intersects any of the boardI in this sequence, then apply "X" to mark these as EXISTING sequence tokens
    team_sequences.each do |ts_bi|
      if (intersect = ts_bi & boardI).size > 1
        intersect.each { |e_bi| tokens[e_bi] = 'X' }
      end
    end

    # now find max length sequence, tracking previously seen 'X'
    seq = [] # indexes of tokens in a row
    max_seq = [] # max length sequence
    tokens.each_with_index do |t, i|
      if t == team
        seq << (i-1) if i > 0 && tokens[i-1] == 'X' # re-use 1
        seq << i
      elsif t == 'X'
        if seq.size > 0
          # in progress seq, we can add only this one.  Then stop
          seq << i
          max_seq = seq if seq.size > max_seq.size
          seq = []
        end
      else
        max_seq = seq if seq.size > max_seq.size
        seq = []
      end
    end
    max_seq = seq if seq.size > max_seq.size

    max_seq.map { |sI| boardI[sI] } if max_seq.size >= sequence_length.to_i
  end

  # combine both directions from tokens_<direction>
  def sequence_in_dir(row, column, team, direction, sequence_length=5)
    s1, b1 = self.send("tokens_#{direction}", row, column, team,  -1, sequence_length)
    s2, b2 = self.send("tokens_#{direction}", row, column, team, 1, sequence_length)
    s = s1.reverse[0...-1] + s2
    b = b1.reverse[0...-1] + b2
    return s, b
  end

  # We can either: return two arrays [tokens, boardI] or a single array with stucts: [ {token: F, boardI: 99}, {}... ]
  # For now we do the double array
  def tokens_horizontal(i, j, team, direction=1, sequence_length=5)
    raise ArgumentError, 'direction must be 1 or -1' unless direction == 1 || direction == -1

    tokens = []
    boardI = []
    steps = 0
    while (j < @size && j >= 0 && steps < sequence_length.to_i)
      t = token_at(i, j)
      break if !t.nil? && t != team
      # Handle Free spaces (give everyone a token on that)
      t = team if self[i, j] == 'F'
      tokens << t
      boardI << i*@size + j
      j += 1*direction
      steps += 1
    end
    tokens[0] = team
    return tokens, boardI
  end

  def tokens_vertical(i, j, team, direction=1, sequence_length=5)
    raise ArgumentError, 'direction must be 1 or -1' unless direction == 1 || direction == -1

    tokens = []
    boardI = []
    steps = 0
    while (i < @size && i >= 0 && steps < sequence_length)
      t = token_at(i, j)
      break if !t.nil? && t != team
      # Handle Free spaces (give everyone a token on that)
      t = team if self[i, j] == 'F'
      tokens << t
      boardI << i*@size + j
      i += 1*direction
      steps += 1
    end
    tokens[0] = team
    return tokens, boardI
  end

  # diagonal, up and to the right, down and to the left.  i and j have same signs
  def tokens_d1(i, j, team, direction=1, sequence_length=5)
    raise ArgumentError, 'direction must be 1 or -1' unless direction == 1 || direction == -1

    tokens = []
    boardI = []
    steps = 0
    while (i < @size && i >= 0 && j < @size && j >= 0  && steps < sequence_length)
      t = token_at(i, j)
      break if !t.nil? && t != team
      # Handle Free spaces (give everyone a token on that)
      t = team if self[i, j] == 'F'
      tokens << t
      boardI << i*@size + j
      i += 1*direction
      j += 1*direction
      steps += 1
    end
    tokens[0] = team
    return tokens, boardI
  end

  # diagonal, up and to the left, down and to the right.  i and j have opposite signs
  def tokens_d2(i, j, team, direction=1, sequence_length=5)
    raise ArgumentError, 'direction must be 1 or -1' unless direction == 1 || direction == -1

    tokens = []
    boardI = []
    steps = 0
    while (i < @size && i >= 0 && j < @size && j >= 0  && steps < sequence_length)
      t = token_at(i, j)
      break if !t.nil? && t != team
      # Handle Free spaces (give everyone a token on that)
      t = team if self[i, j] == 'F'
      tokens << t
      boardI << i*@size + j
      i += -1*direction
      j += 1*direction
      steps += 1
    end
    tokens[0] = team
    return tokens, boardI
  end


  def write_out(name)
    out = self.to_s
    File.open("db/#{name}_board.tsv", "w") { |f| f.write out }
  end

  def to_h
    {"board" => @board, "tokens" => tokens, "sequences" => sequences}
  end

  def self.from_h(h)
    ChainBoard.new(h["board"], h["tokens"], h["sequences"])
  end

  # Tab separated rows of cards (F for Free space, number/suit: 5S)
  def self.load_board(name)
    data = File.read(File.join(Jets.root, "db", "#{name}_board.tsv"))
    ChainBoard.new(data.split(/[\t\n]/))
  end

  def self.next_card(dI)
    card = ChainDeck.card(dI)
    dI += 1
    # Skip jacks
    if card[:number] == 11
      card = ChainDeck.card(dI)
      dI += 1
    end
    [dI, card]
  end

  def self.build_horizontal
    board = Array.new(100)
    dI = 0

    (0..9).each do |i|
      (0..9).each do |j|
        # corners
        if (i == 0 || i == 9) && (j == 0 || j == 9)
          board[i*10 + j] = 'F'
        else
          dI, card = next_card(dI)
          board[i*10 + j] = "#{card[:number]}#{card[:suit]}"
        end
      end
    end

    ChainBoard.new(board)
  end

  def self.build_spiral
    # Spiral matrix algorithm from: https://www.educative.io/edpresso/spiral-matrix-algorithm
    row = 10
    col = 10
    # Defining the boundaries of the matrix.
    top = 0
    bottom = row-1
    left = 0
    right = col - 1

    # Defining the direction in which the array is to be traversed.
    dir = 0

    deckI = 0
    board = Array.new(100)

    while (top <= bottom && left <=right)
      if dir == 0
        (left..right).each do |i| # moving left->right
        if (top == 0 || top == 9) && (i == 0 || i == 9)
          board[top*10 + i] = "F"
        else
          deckI, card = next_card(deckI)
          board[top*10 + i] = "#{card[:number]}#{card[:suit]}"
        end
        end
        # Since we have traversed the whole first
        # row, move down to the next row.
        top +=1
        dir = 1
      elsif dir == 1
        (top..bottom).each do |i| # moving top->bottom
        if (right == 0 || right == 9) && (i == 0 || i == 9)
          board[i*10 + right] = "F"
        else
          deckI, card = next_card(deckI)
          board[i*10 + right] = "#{card[:number]}#{card[:suit]}"
        end
        end

        # Since we have traversed the whole last
        # column, move down to the previous column.
        right -=1
        dir = 2
      elsif dir == 2
        (left..right).each do |i|
          if (bottom == 0 || bottom == 9) && (i == 0 || i ==9)
            board[bottom*10 + i] = "F"
          else
            deckI, card = next_card(deckI)
            board[bottom*10 + i] = "#{card[:number]}#{card[:suit]}"
          end
        end
        # Since we have traversed the whole last
        # row, move down to the previous row.
        bottom -=1
        dir = 3
      elsif dir == 3
        (top..bottom).each do |i|
          if (i==0 || i==9) && (left == 0 || left == 9)
            board[i*10 + left] = "F"
          else
            deckI, card = next_card(deckI)
            board[i*10 + left] = "#{card[:number]}#{card[:suit]}"
          end
        end
        # Since we have traversed the whole first
        # column, move down to the next column.
        left +=1
        dir = 0
      end
    end
    ChainBoard.new(board)
  end
end
