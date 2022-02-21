class StoriesController < ApplicationController
  before_action :set_story, only: %i[ show edit update destroy ]

  # GET /stories or /stories.json
  def index
    @today = Story.upcoming_today
    @news = Story.upcoming_news
  end

  # GET /stories/1 or /stories/1.json
  def show
  end

  # GET /stories/new
  def new
  end

  # GET /stories/1/edit
  def edit
  end

  # POST /stories or /stories.json
  def create
    p = create_story_params.to_h
    puts p
    @story = Story.new
    @story.id = SecureRandom.uuid
    @story.type = p[:type]
    @story.live_date = Date.parse(p[:live_date]).jd if p[:live_date]

    @story.save!
    redirect_to story_path(@story.id), notice: 'Room created!'
  end

  # PATCH/PUT /stories/1 or /stories/1.json
  def update
    if @story.update(story_params)
      redirect_to @story, notice: "Story was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /stories/1 or /stories/1.json
  def destroy
    @story.destroy
    redirect_to stories_url, notice: "Story was successfully destroyed."
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_story
      @story = Story.find(id: params[:id])
    end

    # Only allow a list of trusted parameters through.
    def story_params
      params.require(:story).permit(:id)
    end

    def create_story_params
      params.require(:story).permit(:type, :live_date)
    end
end

