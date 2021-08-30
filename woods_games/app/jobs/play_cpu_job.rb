class PlayCpuJob < ApplicationJob

  def perform(game_id)
    game = ChainGame.find(id: game_id)

    return unless game.table_state['state'] == 'WAITING_TO_PLAY'

    game.play_cpu(1)
    game.save!

    if game.next_player_cpu?
      puts "Still not done, queueing up another...."
      PlayCpuJob.set(wait: game.settings['cpu_wait_time'].to_i.seconds).perform_later(game.id)
    end
    puts "\n-----------------"
  end
end