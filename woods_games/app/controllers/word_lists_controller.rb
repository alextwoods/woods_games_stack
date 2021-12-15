class WordListsController < ApplicationController
  before_action :set_word_list, only: %i[ show edit ]

  # GET /word_lists or /word_lists.json
  def index
    @word_lists = WordList::BONUS_WORD_LISTS
  end

  # GET /word_lists/1 or /word_lists/1.json
  def show
    @words = Word.word_list(@word_list).to_a.map { |w| w.word }.sort
  end

  # GET /word_lists/1/edit
  def edit
    @words = Word.word_list(@word_list).to_a.map { |w| w.word }.sort
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_word_list
      @word_list = params[:id]
    end
end
