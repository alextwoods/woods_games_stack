require 'rails_helper'

describe ZiddlerGame do

  it 'plays a game' do
    game = ZiddlerGame.create_fresh
    game.add_player('a')
    game.add_player('b')

    expect(game.players).to eq(['a', 'b'])

    game.start
    expect(game.data['state']).to eq('PLAYING')
    expect(game.table_state['turn_state']).to eq('WAITING_TO_DRAW')
    expect(game.table_state['dealer']).to eq('b')
    expect(game.table_state['active_player']).to eq('a')
    expect(game.table_state['hands']['a'].size).to eq(3)

    deck_size = game.table_state['deck'].size
    game.draw('a', 'DECK')
    expect(game.table_state['hands']['a'].size).to eq(4)
    expect(game.table_state['deck'].size).to eq(deck_size - 1)

    discard = game.table_state['hands']['a'].first
    game.discard('a', discard)
    expect(game.table_state['hands']['a'].size).to eq(3)
    expect(game.table_state['discard'].last).to eq(discard)
    expect(game.table_state['active_player']).to eq('b')
    expect(game.table_state['turn_state']).to eq('WAITING_TO_DRAW')

    deck_size = game.table_state['deck'].size
    game.draw('b', 'DECK')
    expect(game.table_state['hands']['b'].size).to eq(4)
    expect(game.table_state['deck'].size).to eq(deck_size - 1)

    hand = game.table_state['hands']['b']
    game.laydown('b', {words: [[hand[0], hand[1]], [hand[2]]], leftover: [], discard: hand[3] })
    expect(game.table_state['hands']['b'].size).to eq(0)
    expect(game.table_state['discard'].last).to eq(hand[3])
    expect(game.table_state['active_player']).to eq('a')
    expect(game.table_state['turn_state']).to eq('WAITING_TO_DRAW')

    deck_size = game.table_state['deck'].size
    game.draw('a', 'DECK')
    expect(game.table_state['hands']['a'].size).to eq(4)
    expect(game.table_state['deck'].size).to eq(deck_size - 1)

    # final turn - must laydown
    expect{ game.discard('a', discard) }.to raise_error(StandardError)

    hand = game.table_state['hands']['a']
    game.laydown('a', {words: [[hand[0], hand[1]]], leftover: [hand[2]], discard: hand[3] })
    expect(game.table_state['hands']['a'].size).to eq(0)
    expect(game.table_state['discard'].last).to eq(hand[3])

    expect(game.data['score']['b']).to be > 0
    expect(game.table_state['turn_state']).to eq('ROUND_COMPLETE')

  end

  it 'correctly computes the longest word bonus' do
    game_data = JSON.load(File.read('spec/fixtures/game_longest_word.json'))
    game = ZiddlerGame.new
    game.data = game_data['data']
    game.next_turn('cathy')

    # TODO: This test works.  Issue may have been with either deck or laydown
  end
end
