class StoriesController < ApplicationController
  before_action :set_story, only: %i[ show edit save destroy generate]

  @@openai = OpenAiClient.new(key: Rails.application.credentials[:openai_key])

  # GET /stories or /stories.json
  def index
    @today = Story.upcoming_today
    @news = Story.upcoming_news
  end

  # GET /stories/archive
  def archive
    # TODO: Add some pagination
    @stories = Story.archive
  end

  # GET /stories/1 or /stories/1.json
  def show
  end

  # GET /stories/new
  def new
    @type = params.permit(:type)["type"] || "news"
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
    @story.status = "draft"
    @story.log = [{event: "created", at: Time.current.iso8601, by: 'user'}]

    @story.save!
    redirect_to edit_story_path(@story.id), notice: 'Story created!'
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
      update_params['body'] = update_params['body']['content']
    end

    puts "Updating with: #{update_params}"
    updated_fields = @story.set_attrs(update_params)
    @story.log << [{event: "updated", at: Time.current.iso8601, by: 'user', updated_fields: updated_fields}]
    if @story.save!
      redirect_to story_path(@story.id), notice: "Content was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def generate
    generate_params = generate_story_params.to_h.symbolize_keys
    puts "Generating a new story with: #{generate_params}"
    generate_params[:temperature] = generate_params[:temperature].to_f if generate_params[:temperature]
    generate_params[:presence_penalty] = generate_params[:presence_penalty].to_f if generate_params[:presence_penalty]
    generate_params[:frequency_penalty] = generate_params[:frequency_penalty].to_f if generate_params[:frequency_penalty]


    resp = @@openai.complete(**generate_params)
    generated = resp['choices'].first['text']
    puts generated
    body = generated.strip.split("\n\n").map { |p| "<div>#{p.gsub("\n", "<br/>")}<br/><br/></div>"}.join("\n")
    puts "\n---------------\n"
    puts body
    @story.body = body
    @story.author_info = "GPT-3/text-davinci-001"
    @story.prompt = generate_params[:prompt]
    @story.status = "draft"
    @story.log << [{event: "generated", at: Time.current.iso8601, by: 'user', prompt: generate_params[:prompt]}]

    @story.save!
    redirect_to edit_story_path(@story.id), notice: "New content was generated"
  end

  # DELETE /stories/1 or /stories/1.json
  def destroy
    @story.delete! if @story
    redirect_to stories_url, notice: "Story was successfully destroyed."
  end

  # GET /stories/publish_content_job
  def publish_content_job
    job = PublishContentJob.perform_later
    render json: job
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_story
      @story = Story.find(id: params[:id])
      @story.log ||= []
    end

    # Only allow a list of trusted parameters through.
    def story_params
      params.require(:story).permit(:live_date, :title, :author_info, :status, body: {})
    end

    def create_story_params
      params.require(:story).permit(:type, :live_date)
    end

  def generate_story_params
    params.require(:generate).permit(:prompt, :temperature, :presence_penalty, :frequency_penalty)
  end
end

