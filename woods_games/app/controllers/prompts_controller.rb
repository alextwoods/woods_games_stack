class PromptsController < ApplicationController
  before_action :set_prompt, only: %i[ destroy ]

  # GET /prompts/new
  def new
    @type = params.permit(:type)["type"] || "news"
  end

  # GET /prompts
  def index
    @prompts = Prompt.scan
    @news_prompts = @prompts.select { |p| p.type == "news" }
    @today_prompts = @prompts.select { |p| p.type == "today" }
  end

  # POST /prompts or /prompts.json
  def create
    @prompt = Prompt.new(id: SecureRandom.uuid, prompt: params.require(:prompt), type: params.require(:type))

    @prompt.save
    redirect_to prompts_path, notice: "Added #{@prompt.type} prompt: #{@prompt.prompt}"
  end

  # DELETE /prompts/1 or /prompts/1.json
  def destroy
    @prompt.delete! if @prompt
    redirect_to prompts_path, notice: "#{params[:id]} was successfully removed."
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_prompt
    @prompt = Prompt.find(id: params[:id])
  end

  # Only allow a list of trusted parameters through.
  def prompt_params
    params.require([:prompt, :type])
  end
end
