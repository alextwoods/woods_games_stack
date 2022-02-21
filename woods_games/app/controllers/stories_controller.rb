class StoriesController < ApplicationController
  before_action :set_story, only: %i[ show edit save destroy ]

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
    @story = Story.new
    @story.id = SecureRandom.uuid
    @story.type = p[:type]
    @story.live_date = Date.parse(p[:live_date]).jd if p[:live_date]

    @story.save!
    redirect_to story_path(@story.id), notice: 'Room created!'
  end

  # TODO: this is all messed up.  the put form thing does not work
  # form_tag is supposed to add a method(put), which then directs to update
  # it does not.  So we just create a new method/route and use post.
  def save
    update_params = story_params.to_h
    if (update_params.key?('live_date'))
      update_params['live_date'] = Date.parse(update_params['live_date']).jd
    end

    if (Hash === update_params['body'])
      puts "Fixing up body...."
      update_params['body'] = update_params['body']['content']
    end

    puts "Updating with: #{update_params}"
    if @story.update(update_params)
      redirect_to story_path(@story.id), notice: "Story was successfully updated."
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
      puts params.inspect
      params.require(:story).permit(:live_date, :title, :prompt, :author_info, :status, body: {})
    end

    def create_story_params
      params.require(:story).permit(:type, :live_date)
    end
end

