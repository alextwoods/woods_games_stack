require 'rails_helper'

describe ChainBoard do
  describe '.build_horizontal' do
    let(:b) { ChainBoard.build_horizontal }
    it 'sets the corners as free' do
      expect(b[0,0]).to eq 'F'
      expect(b[0,9]).to eq 'F'
      expect(b[9,0]).to eq 'F'
      expect(b[9,9]).to eq 'F'
    end

    it 'lays cards out in order horizontally' do
      expect(b[0,1]).to eq '1H'
      expect(b[0,2]).to eq '2H'
      expect(b[0,3]).to eq '3H'

      expect(b[1,0]).to eq '9H'
      expect(b[1,1]).to eq '10H'
      # SKIPS THE JACK
      expect(b[1,2]).to eq '12H'

    end
  end

  describe '.build_spiral' do
    let(:b) { ChainBoard.build_spiral }
    it 'sets the corners as free' do
      expect(b[0,0]).to eq 'F'
      expect(b[0,9]).to eq 'F'
      expect(b[9,0]).to eq 'F'
      expect(b[9,9]).to eq 'F'
    end

    it 'lays cards out in a spiral' do
      expect(b[0,1]).to eq '1H'
      expect(b[0,2]).to eq '2H'
      expect(b[0,3]).to eq '3H'

      expect(b[1,9]).to eq '9H'
      expect(b[2,9]).to eq '10H'
      # SKIPS THE JACK
      expect(b[3,9]).to eq '12H'
    end
  end

  describe '#board_loc' do
    let(:b) { ChainBoard.build_horizontal }

    it 'returns the locations on the board' do
      locs = b.board_loc(number: 1, suit: 'H')
      expect(locs).to eq([1,50])
    end
  end

  describe '#valid_play?' do
    let(:board) { ChainBoard.build_horizontal }
    let(:cardI) { 1 }
    let(:card) { ChainDeck.card(cardI) }
    let(:team) { 'R' }

    it 'returns true when valid' do
      expect(board.valid_play?(card, 0, 2, team)).to be true
    end


    it 'returns false when card doesnt match' do
      expect(board.valid_play?(card, 0, 0, team)).to be false
    end

    it 'returns false when location is full' do
      board.set_token(0,2, 'G')
      expect(board.valid_play?(card, 0, 2, team)).to be false
    end
  end

  describe '#tokens_horizontal' do
    let(:board) { ChainBoard.build_horizontal }

    it 'returns tokens to the right' do
      board.set_token(0,2, 'R')
      board.set_token(0,3, 'R')
      board.set_token(0,4, 'R')
      tokens, boardI = board.tokens_horizontal(0,1, 'R', 1)
      expect(tokens).to eq ['R', 'R', 'R', 'R', nil]
      expect(boardI).to eq [1,2,3,4,5]
    end

    it 'stops for other colors' do
      board.set_token(0,2, 'R')
      board.set_token(0,3, 'G')
      board.set_token(0,4, 'R')
      tokens, boardI = board.tokens_horizontal(0,1, 'R', 1)
      expect(tokens).to eq ['R', 'R']
      expect(boardI).to eq [1, 2]
    end

    it 'returns tokens to the left and gives a token for the free space' do
      board.set_token(0,1, 'R')
      board.set_token(0,2, 'R')
      board.set_token(0,3, 'R')
      tokens, boardI = board.tokens_horizontal(0,4, 'R', -1)
      expect(tokens).to eq ['R', 'R', 'R', 'R', 'R']
    end
  end

  describe '#tokens_vertical' do
    let(:board) { ChainBoard.build_horizontal }

    it 'returns tokens up' do
      board.set_token(2,0, 'R')
      board.set_token(3,0, 'R')
      board.set_token(4,0, 'R')
      tokens, boardI = board.tokens_vertical(1,0, 'R', 1)
      expect(tokens).to eq ['R', 'R', 'R', 'R', nil]
    end

    it 'stops for other colors' do
      board.set_token(2,0, 'R')
      board.set_token(3,0, 'G')
      board.set_token(4,0, 'R')
      tokens, boardI = board.tokens_vertical(1,0, 'R', 1)
      expect(tokens).to eq ['R', 'R']
    end

    it 'returns tokens below and gives a token for the free space' do
      board.set_token(1,0, 'R')
      board.set_token(2,0, 'R')
      board.set_token(3,0, 'R')
      tokens, boardI = board.tokens_vertical(4,0, 'R', -1)
      expect(tokens).to eq ['R', 'R', 'R', 'R', 'R']
    end
  end

  describe '#tokens_d1' do
    let(:board) { ChainBoard.build_horizontal }

    it 'returns tokens up and right' do
      board.set_token(2,2, 'R')
      board.set_token(3,3, 'R')
      board.set_token(4,4, 'R')
      tokens, boardI = board.tokens_d1(1,1, 'R', 1)
      expect(tokens).to eq ['R', 'R', 'R', 'R', nil]
    end

    it 'stops for other colors' do
      board.set_token(2,2, 'R')
      board.set_token(3,3, 'G')
      board.set_token(4,4, 'R')
      tokens, boardI = board.tokens_d1(1,1, 'R', 1)
      expect(tokens).to eq ['R', 'R']
    end

    it 'returns tokens below and left and gives a token for the free space' do
      board.set_token(1,1, 'R')
      board.set_token(2,2, 'R')
      board.set_token(3,3, 'R')
      tokens, boardI = board.tokens_d1(4,4, 'R', -1)
      expect(tokens).to eq ['R', 'R', 'R', 'R', 'R']
    end
  end

  describe '#tokens_d2' do
    let(:board) { ChainBoard.build_horizontal }

    it 'returns tokens up and left' do
      board.set_token(2,7, 'R')
      board.set_token(3,6, 'R')
      board.set_token(4,5, 'R')
      tokens, boardI = board.tokens_d2(1,8, 'R', -1)
      expect(tokens).to eq ['R', 'R', 'R', 'R', nil]
    end

    it 'stops for other colors' do
      board.set_token(2,7, 'R')
      board.set_token(3,6, 'G')
      board.set_token(4,5, 'R')
      tokens, boardI = board.tokens_d2(1,8, 'R', -1)
      expect(tokens).to eq ['R', 'R']
    end

    it 'returns tokens below and right and gives a token for the free space' do
      board.set_token(1,8, 'R')
      board.set_token(2,7, 'R')
      board.set_token(3,6, 'R')
      tokens, boardI = board.tokens_d2(4,5, 'R', 1)
      expect(tokens).to eq ['R', 'R', 'R', 'R', 'R']
    end
  end

  describe '#sequences_in_dir' do
    let(:board) { ChainBoard.build_horizontal }

    it 'combines both directions' do
      # [F _ R _ X R R _ _ R]
      board.set_token(0,2, 'R')
      board.set_token(0,5, 'R')
      board.set_token(0,6, 'R')
      tokens, boardI = board.sequence_in_dir(0,4, 'R', :horizontal)
      expect(tokens).to eq ['R', nil, 'R', nil, 'R', 'R', 'R', nil, nil]
      expect(boardI).to eq [0,1,2,3,4,5,6,7,8]

      # board.set_token(0,4, 'R')
      # new_s = board.new_sequences_at(0, 4, 'R', 3)
      # puts new_s
      # puts board
    end
  end

  describe '#check_new_sequence' do
    let(:seq_len) { 3 }
    let(:team) { 'R' }
    context 'horizontal: existing seq on left' do
      # [ 0 1 2 3 4 5]
      # [ O O O R _ _] -> This is NOT a new seq
      # [ O O O R R _] -> This is

      let(:existing) { {team => [ [0,1,2] ]} }
      let(:board) { ChainBoard.build_horizontal.tap { |b| b.sequences = existing} }

      let(:boardI) { [0,1,2,3,4,5] }

      context 'only 1 new' do
        let(:tokens) { [team, team, team, team, nil, nil]}
        it 'is not a new sequence' do
          out = board.check_new_sequence(tokens, boardI, team, seq_len)
          expect(out).to be_nil
        end
      end

      context '2 new' do
        let(:tokens) { [team, team, team, team, team, nil]}
        it 'is a new sequence' do
          out = board.check_new_sequence(tokens, boardI, team, seq_len)
          expect(out).to eq [2,3,4]
        end
      end

      context 'gap in new' do
        let(:tokens) { [team, team, team, team, nil, team]}
        it 'is not a new sequence' do
          out = board.check_new_sequence(tokens, boardI, team, seq_len)
          expect(out).to be_nil
        end
      end
    end

    context 'horizontal: existing seq on right' do
      # [ 0 1 2 3 4 5]
      # [ _ _ R O O O] -> This is NOT a new seq
      # [ _ R R O O O] -> This is

      let(:existing) { {team => [ [3, 4, 5] ]} }
      let(:board) { ChainBoard.build_horizontal.tap { |b| b.sequences = existing} }

      let(:boardI) { [0,1,2,3,4,5] }

      context 'only 1 new' do
        let(:tokens) { [nil, nil, team, team, team, team]}
        it 'is not a new sequence' do
          out = board.check_new_sequence(tokens, boardI, team, seq_len)
          expect(out).to be_nil
        end
      end

      context '2 new' do
        let(:tokens) { [nil, team, team, team, team, team]}
        it 'is a new sequence' do
          out = board.check_new_sequence(tokens, boardI, team, seq_len)
          expect(out).to eq [1, 2, 3]
        end
      end
    end
  end
  let(:board) { ChainBoard.build_horizontal }

  describe '#score_dir' do
    let(:seq_len) { 3 }
    it 'scores 0 for < sequence length' do
      s = [1, 1]
      expect( board.score_dir(s, seq_len) ).to eq 0
    end

    # [1, 1, nil] => this is close to a seq.
    it 'returns a big number for close' do
      s = [1, 1, nil]
      expect( board.score_dir(s, seq_len) ).to eq seq_len
    end

    it 'returns a small number for a bit further away' do
      s = [1, nil, nil]
      expect( board.score_dir(s, seq_len) ).to be < seq_len
    end

    it 'returns a very big number for a sequence' do
      s = [1, 1, 1]
      expect( board.score_dir(s, seq_len) ).to be > 1000
    end

    context 'sequence_length: 5' do
      let(:seq_len) { 5 }
      it 'scores in order' do
        s0 = board.score_dir([1]*0 + [nil]*5, seq_len)
        s1 = board.score_dir([1]*1 + [nil]*4, seq_len)
        s2 = board.score_dir([1]*2 + [nil]*3, seq_len)
        s3 = board.score_dir([1]*3 + [nil]*2, seq_len)
        s4 = board.score_dir([1]*4 + [nil]*1, seq_len)
        s5 = board.score_dir([1]*5 + [nil]*0, seq_len)

        expect(s1).to be > s0
        expect(s2).to be > s1
        expect(s3).to be > s2
        expect(s4).to be > s3
        expect(s5).to be > s4
      end
    end
  end

  describe 'score_move' do
    # 36.020k (± 6.0%) i/s
    # it 'benchmarks' do
    #   require 'benchmark/ips'
    #   board = ChainBoard.build_horizontal
    #   Benchmark.ips do |x|
    #     x.report("score_move") { board.score_move(rand(10), rand(10), "R")}
    #   end
    # end
  end
end