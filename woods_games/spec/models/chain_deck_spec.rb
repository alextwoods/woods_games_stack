require 'rails_helper'

describe ChainDeck do
  describe '.card' do
    it 'returns cards in order' do
      expect(ChainDeck.card(0)).to eq({number: 1, suit: 'H'})
      expect(ChainDeck.card(1)).to eq({number: 2, suit: 'H'})
    end

    it 'returns 4 suits of 13' do
      expect(ChainDeck.card(0)).to eq({number: 1, suit: 'H'})
      expect(ChainDeck.card(13)).to eq({number: 1, suit: 'S'})
      expect(ChainDeck.card(26)).to eq({number: 1, suit: 'D'})
      expect(ChainDeck.card(39)).to eq({number: 1, suit: 'C'})
    end

    it 'supports multiple decks' do
      expect(ChainDeck.card(52 + 0)).to eq({number: 1, suit: 'H'})
      expect(ChainDeck.card(52 + 1)).to eq({number: 2, suit: 'H'})
      expect(ChainDeck.card(52 + 13)).to eq({number: 1, suit: 'S'})
      expect(ChainDeck.card(52 + 39)).to eq({number: 1, suit: 'C'})
    end
  end

  describe '.i' do
    it 'returns the index in the first two decks' do
      expect(ChainDeck.i(ChainDeck.card(0))).to eq([0,52])
      expect(ChainDeck.i(ChainDeck.card(1))).to eq([1,53])
      expect(ChainDeck.i(ChainDeck.card(39))).to eq([39,91])
    end

    it 'converts strings and returns the index' do
      expect(ChainDeck.i('8D')).to eq(ChainDeck.i(number: 8, suit: 'D'))
    end

  end
end