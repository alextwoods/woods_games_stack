
class ChainDeck

  SUIT_S = %w[H S D C]

  # Only model a standard Deck
  # 2x [1-13 X H,S,D,C].

  #   0 1 2 3    4 5 6 7
  # H[0 1 2 3] S[0 1 2 3]

  def self.size
    return 104
  end

  def self.card(i)
    i = i % 52 # divide two decks into 2 of 52 cards
    suit = SUIT_S[i / 13] # divide deck into 4 suits of 13 cards each
    number = (i % 13) + 1 # get the card number (add 1 to fix zero index)
    {suit: suit, number: number}
  end

  # the inverse of the above
  # return the indecies (in the first 2 decks) for the card
  def self.i(card)
    card = s_to_card(card) if card.is_a?(String)
    suit = card[:suit]
    number = card[:number]
    s = SUIT_S.find_index(suit)
    cI = s*13 + (number-1)
    [cI, cI+52]
  end

  def self.s_to_card(s)
    m = /(\d+)([HSDC])/.match(s)
    {number: m[1].to_i, suit: m[2]}
  end


  # one eyed jacks, hearts and spades
  def self.anti_wild?(card)
    card[:number] == 11 && (card[:suit] == "H" || card[:suit] == "S")
  end

  # two eyed jacks, Diamonds and Clubs
  def self.wild?(card)
    card[:number] == 11 && (card[:suit] == "D" || card[:suit] == "C")
  end
end
