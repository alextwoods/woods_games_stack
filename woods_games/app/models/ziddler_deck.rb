class ZiddlerDeck

  def self.standard_deck
    @@standard_deck ||= load_deck(:standard)
  end

  # Expect a single line of Letter Value Quantity
  # Returns an array of [letter, value] pairs representing cards
  # Cards should be referenced by index and looked up in this array
  def self.load_deck(deck)
    data = File.read(File.join(Rails.root, "db", "#{deck}_deck.tsv"))
    deck = []
    data.split.each_slice(3) do |letter, value, quantity|
      quantity.to_i.times do
        deck << [letter.strip, value]
      end
    end
    deck
  end
end
