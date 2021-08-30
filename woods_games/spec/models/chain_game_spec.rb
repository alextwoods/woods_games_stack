require 'rails_helper'

describe ChainGame do

  it 'plays a game' do
    game = ChainGame.create_fresh
    game.add_cpu
    game.add_cpu
    game.settings['sequence_length'] = 3
    game.start

    game.play_cpu(50)
    puts game.get_board
  end
end