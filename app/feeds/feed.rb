require 'blue_factory/errors'
require 'rainbow'
require 'time'

require_relative '../models/feed_post'

class Feed
  DEFAULT_LIMIT = 50
  MAX_LIMIT = 100

  # any unique number to use as a key in the database
  def feed_id
    raise NotImplementedError
  end

  def post_matches?(post)
    raise NotImplementedError
  end

  # name of your feed, e.g. "What's Hot"
  def display_name
    raise NotImplementedError
  end

  # (optional) description of the feed, e.g. "Top trending content from the whole network"
  def description
    nil
  end

  # (optional) path of the feed avatar file
  def avatar_file
    nil
  end

  # if the feed matches posts using keywords/regexps, highlight these keywords in the passed text
  def colored_text(text)
    text
  end

  def get_posts(params)
    limit = check_query_limit(params)
    query = FeedPost.where(feed_id: feed_id).joins(:post).select('posts.repo, posts.rkey, feed_posts.time, post_id')
      .order('feed_posts.time DESC, post_id DESC').limit(limit)

    if params[:cursor].to_s != ""
      time, last_id = parse_cursor(params)
      query = query.where("feed_posts.time < ? OR (feed_posts.time = ? AND post_id < ?)", time, time, last_id)
    end

    posts = query.to_a
    last = posts.last

    cursor = last && sprintf('%.06f', last.time.to_f) + ':' + last.post_id.to_s

    { cursor: cursor, posts: posts.map { |p| 'at://' + p.repo + '/app.bsky.feed.post/' + p.rkey }}
  end


  private

  def check_query_limit(params)
    if params[:limit]
      limit = params[:limit].to_i
      (limit < 0) ? 0 : [limit, MAX_LIMIT].min
    else
      DEFAULT_LIMIT
    end
  end

  def parse_cursor(params)
    parts = params[:cursor].split(':')

    if parts.length != 2 || parts[0] !~ /^\d+(\.\d+)?$/ || parts[1] !~ /^\d+$/
      raise BlueFactory::InvalidRequestError.new("Malformed cursor")
    end

    sec = parts[0].to_i
    usec = (parts[0].to_f * 1_000_000).to_i % 1_000_000
    time = Time.at(sec, usec)

    last_id = parts[1].to_i

    [time, last_id]
  end
end
