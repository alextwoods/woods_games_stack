include BCrypt

class RoomsController < ApplicationController

  before_action :set_room, only: %i[ show destroy]

  # GET /rooms
  def index
    redirect_to room_path(session[:room]) if session[:room]
  end

  # GET /rooms/1
  def show
    if !@room || session[:room] != @room.id
      puts "Invalid room session, clearing and redirecting to index"
      session[:room] = nil
      redirect_to rooms_path, alert: "Invalid room session, clearing and redirecting to index"
      return
    end

    @chain_games = ChainGame.where_room(@room.id)
    @chain_games_joinable, @chain_games_other = @chain_games.partition { |g| g.data['state'] == 'WAITING_FOR_PLAYERS' }

    @ziddler_games = ZiddlerGame.where_room(@room.id)
    @ziddler_games_joinable, @ziddler_games_other = @ziddler_games.partition { |g| g.data['state'] == 'WAITING_FOR_PLAYERS' }

    @word_mine_games = WordMineGame.where_room(@room.id)
    @word_mine_games_joinable, @word_mine_games_other = @word_mine_games.partition { |g| g.data['state'] == 'WAITING_FOR_PLAYERS' }


  end

  # POST /rooms/join
  def join
    puts "Trying to join: #{room_params}"
    @room = Room.find(id: room_params[:id])
    if @room && Password.new(@room.passphrase) == room_params[:passphrase].downcase
      puts "Joined room: #{@room.id}"
      session[:room] = @room.id
      redirect_to room_path(@room.id), notice: "Joined room: #{@room.id}"
    else
      puts "Room doesn't exist or passhprase mismatch: #{@room&.passphrase} -> #{room_params[:passphrase].downcase}"
      redirect_to rooms_path, alert: "Room doesn't exist or passhprase mismatch"
    end
  end

  # GET /rooms/leave
  def leave
    puts "Leaving room: #{session[:room]}"
    session[:room] = nil
    redirect_to rooms_path, notice: 'Successfully left room'
  end

  # GET /rooms/new
  def new
    @room = Room.new
    puts @room
  end

  # GET /rooms/1/edit
  def edit
  end

  # POST /rooms or /rooms.json
  def create
    p = room_params.to_h
    @room = Room.new # unclear why, but new with the attributes below does not work.  just use setters.
    @room.id = p[:id]
    @room.passphrase = Password.create(room_params[:passphrase].downcase)
    puts @room.inspect
    puts "Passphrase: #{@room.passphrase}"
    @room.save!
    session[:room] = @room.id
    redirect_to room_path(@room.id), notice: 'Room created!'
  end


  # DELETE /rooms/1 or /rooms/1.json
  def destroy
    # TODO
  end

  # todo: not sure what this route is used for, but jets requires it...
  def delete
    # TODO
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_room
    @room = Room.find(id: params[:id])
  end

  # Only allow a list of trusted parameters through.
  def room_params
    params.require(:room).permit(:id, :passphrase)
  end
end
