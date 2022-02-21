require 'faraday'
require 'faraday/net_http'

class OpenAiClient

  # Create with:
  # openai = OpenAiClient.new(key: Rails.application.credentials[:openai_key])
  def initialize(key:)
    @key = key
  end

  def engines
    con = Faraday.new('https://api.openai.com')
    resp = con.get('/v1/engines') do |req|
      req.headers['Authorization'] = "Bearer #{@key}"
    end
    JSON.parse(resp.body)
  end

  def complete(engine_id: 'text-davinci-001',
               prompt: "write a story",
               max_tokens: 2000,
               temperature: 0.7,
               presence_penalty: 0.0,
               frequency_penalty: 0.0,
               logprobs: nil
               )
    body = {
      prompt: prompt,
      max_tokens: max_tokens,
      temperature: temperature,
      presence_penalty: presence_penalty,
      frequency_penalty: frequency_penalty,
      logprobs: logprobs
    }
    con = Faraday.new('https://api.openai.com')
    resp = con.post("/v1/engines/#{engine_id}/completions") do |req|
      req.headers['Authorization'] = "Bearer #{@key}"
      req.headers['Content-Type'] = 'Application/json'
      req.body = JSON.dump(body)
    end
    JSON.parse(resp.body)
  end
end
