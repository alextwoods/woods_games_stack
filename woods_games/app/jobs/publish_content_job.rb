class PublishContentJob < ApplicationJob
  queue_as :default

  TODAY_DIST_ID = 'EJYA8AHVQ842Q'
  NEWS_DIST_ID = 'E1N68KLGTLXCZ9'

  def perform(*args)

    @s3 = Aws::S3::Client.new
    @cloudfront = Aws::CloudFront::Client.new

    today = Story.upcoming_today
    news = Story.upcoming_news

    publish_story(today.first, 'pooping.today', TODAY_DIST_ID)

    publish_story(news.first, 'pooping.news', NEWS_DIST_ID)
  end

  def publish_story(story, site, dist_id)
    today_jd = Date.today.jd

    # Check for a story that is ready and is for today
    unless (story && story.status == "ready" && today_jd == story.live_date.to_i)
      puts "No content ready to publish to #{site}"
      puts "Story '#{story.title}' status: #{story.status} for: #{Date.jd(story.live_date)}"
      return
    end

    puts "Content ready to publish on #{site}: #{story.title}"
    story = Story.find(id: story.id) # fetch the entire story
    new_today_html = render_index(story)

    @s3.put_object(bucket: site, key: "#{story.id}.html", body: new_today_html)
    @s3.copy_object(bucket: site, key: "index.html", copy_source: "#{site}/#{story.id}.html")

    puts "Story copied to S3 at /index.html and /#{story.id}.html. Creating CloudFront Invalidation..."

    @cloudfront.create_invalidation({
                                     distribution_id: dist_id,
                                     invalidation_batch: {
                                       paths: {
                                         quantity: 1,
                                         items: ["/index.html"],
                                       },
                                       caller_reference: "PublishContentJob",
                                     },
                                   })

    puts "Cloudfront invalidation created.  Story should be visible on #{site} shortly."

    story.status = "published"
    story.log << {event: 'published', at: Time.current.iso8601, by: 'PublishContentJob'}
    story.save!
  end

  def render_index(story)
    ac = ActionController::Base.new()
    ac.instance_variable_set(:@content, story.body)
    ac.instance_variable_set(:@title, story.title)
    ac.instance_variable_set(:@live_date, Date.jd(story.live_date))

    ac.render_to_string(
      "stories/news_index",
      layouts: false)
  end
end
