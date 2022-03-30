require 'rails_helper'

describe WordMineGame do

  it 'plays a game' do
    game = WordMineGame.create_fresh
    game.add_player('a')
    game.add_player('b')

    expect(game.players).to eq(['a', 'b'])

    game.start
    expect(game.data['state']).to eq('PLAYING')
    expect(game.table_state['turn_state']).to eq('WAITING_TO_PLAY')

    expect(game.table_state['laid_out'].size).to eq(3)
    expect(game.table_state['laid_out'][0].size).to eq(4)

    player = game.table_state['active_player']
    player_state = game.table_state['players_state'][player]
    expect(player_state['hand'].size).to eq(4)

    # have the active player draw a card
    game.draw_action(player)
    expect(player_state['deck'].size).to eq(4)
    expect(player_state['hand'].size).to eq(6)
    expect(game.table_state['active_player']).not_to eq(player)

    # new turn, new active player
    player = game.table_state['active_player']
    player_state = game.table_state['players_state'][player]
    expect(player_state['hand'].size).to eq(4) # they've also drawn a card
    expect(player_state['actions']).to eq(1) # they have an action

    board_card = {'card_i' => game.table_state['laid_out'][1][2], 'row' => 1, 'col' => 2 }
    word = player_state['hand'].first(2) + [board_card['card_i']]
    game.play_action(player, word, board_card)
    expect(player_state['hand'].size).to eq(2)
    expect(player_state['discard']).to eq(word)
    expect(player_state['played'].size).to eq(1)
    expect(player_state['played'].size).to eq(1)
    expect(player_state['score']).to eq(player_state['played'][0][:score])

    expect(player_state['actions']).to eq(0)
    expect(game.table_state['active_player']).not_to eq(player) # turns over, new active player

    # new turn, new active player
    player = game.table_state['active_player']
    player_state = game.table_state['players_state'][player]

    player_state['score'] = 100 # give them enough points to buy a card
    board_card = {'card_i' => game.table_state['laid_out'][1][2], 'row' => 1, 'col' => 2 }
    expect(player_state['deck'].size).to eq(3)
    expect(player_state['hand'].size).to eq(7)
    game.buy_action(player, board_card)
    expect(player_state['hand'].size).to eq(8)
    expect(player_state['score'].size).to be < 100

    # new turn, new active player
    player = game.table_state['active_player']
    player_state = game.table_state['players_state'][player]

    expect(player_state['deck'].size).to eq(5)
    expect(player_state['hand'].size).to eq(3)
    expect(player_state['discard'].size).to eq(3)

    game.shuffle_action(player)

    expect(player_state['deck'].size).to eq(8)
    expect(player_state['hand'].size).to eq(3)
    expect(player_state['discard'].size).to eq(0)

  end
end
