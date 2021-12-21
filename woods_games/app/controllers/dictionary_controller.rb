class DictionaryController < ApplicationController

  # GET /dictionary
  def index
    puts "At our index...."
    @searched_word = params.permit('word')['word']&.upcase
    if @searched_word
      @definition = Dictionary.find(word: @searched_word) || :not_found
    end
  end

end
