class GenerateNewStoriesJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # unclear if the first(7) limits us correctly....
    today = Story.upcoming_today.first(7).to_a
    news = Story.upcoming_news.first(7).to_a

    today_jd = Date.today.jd

    prompts = Prompt.scan
    news_prompts = prompts.select { |p| p.type == "news" }
    today_prompts = prompts.select { |p| p.type == "today" }

    # Find days over the next week that do not have content
    (today_jd..today_jd+7).each do |jd|
      if (!today.any? { |s| s.live_date == jd } )
        puts "No today (stories) for: #{Date.jd(jd)}"
      end
    end

    (today_jd..today_jd+7).each do |jd|
      if (!news.any? { |s| s.live_date == jd } )
        puts "No news for: #{Date.jd(jd)}"
      end
    end

  end

  def generate_content(jd, type, prompt)
    story = Story.new
    story.id = SecureRandom.uuid
    story.type = type
    story.live_date = jd
    story.status = 'draft'
    story.title = prompt

    # generate

  end
end
