class WordMineDeck

  COMMON_DECK = 0
  MEDIUM_DECK = 1
  RARE_DECK = 2

  def self.standard_deck
    @@standard_deck ||= load_deck(:standard)
  end

  # Expect a single line of Letter Value Quantity
  # Start with the ziddler deck, load it and multiply it by n_decks
  # Then divide the deck into common, medium and rare (by points).
  # Returns an array of [letter, value, deckI] pairs representing cards
  # Cards should be referenced by index and looked up in this array
  def self.load_deck(deck, n_decks=2)
    data = File.read(File.join(Rails.root, "db", "#{deck}_deck.tsv"))
    deck = []
    data.split.each_slice(3) do |letter, value, quantity|
      value = value.to_i
      (quantity.to_i * n_decks).times do
        deck << [letter.strip, value, deck_for_card(letter, value, quantity)]
      end
    end
    deck
  end

  def self.deck_for_card(letter, value, quantity)
    if value < 4
      COMMON_DECK
    elsif value < 8
      MEDIUM_DECK
    else
      RARE_DECK
    end
  end

end
