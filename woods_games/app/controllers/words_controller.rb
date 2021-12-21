class WordsController < ApplicationController
  before_action :set_word, only: %i[ show edit update destroy ]

  # GET /words/new
  def new
    @word = Word.new
  end

  # GET /words/1/edit
  def edit
  end

  # POST /words or /words.json
  def create
    @word = Word.new(id: params[:word_list_id], word: word_param)

    begin
      @word.save
      redirect_to edit_word_list_path(@word.id), notice: "Added #{@word.word}"
    rescue Aws::Record::Errors::ConditionalWriteFailed
      redirect_to edit_word_list_path(params[:word_list_id]), alert: "#{word_param} already exists."
    end
  end

  # DELETE /words/1 or /words/1.json
  def destroy
    @word.delete! if @word
    redirect_to edit_word_list_path(params[:word_list_id]), notice: "#{params[:id]} was successfully removed."
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_word
      @word = Word.find(id: params[:word_list_id], word: params[:id])
    end

    # Only allow a list of trusted parameters through.
    def word_param
      params.require(:word)
    end
end
