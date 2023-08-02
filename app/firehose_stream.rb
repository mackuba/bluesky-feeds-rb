require 'json'
require 'sinatra/activerecord'
require 'skyfall'

require_relative 'config'
require_relative 'models/feed_post'
require_relative 'models/post'
require_relative 'models/subscription'

class FirehoseStream
  attr_accessor :show_progress, :log_status, :log_posts, :save_posts, :replay_events

  def initialize
    @env = (ENV['APP_ENV'] || ENV['RACK_ENV'] || :development).to_sym
    @service = 'bsky.social'

    @show_progress = (@env == :development) ? true : false
    @log_status = true
    @log_posts = (@env == :development) ? :matching : false
    @save_posts = (@env == :development) ? :all : :matching
    @replay_events = (@env == :development) ? false : true

    @feeds = BlueFactory.all_feeds.select(&:is_updating?)
  end

  def start
    return if @sky

    last_cursor = load_or_init_cursor
    cursor = @replay_events ? last_cursor : nil

    @sky = Skyfall::Stream.new(@service, :subscribe_repos, cursor)

    @sky.on_message do |m|
      handle_message(m)
    end

    if @log_status
      @sky.on_connecting { |u| puts "Connecting to #{u}..." }
      @sky.on_connect {
        @replaying = !!(cursor)
        puts "Connected #{Time.now} ✓"
      }
      @sky.on_disconnect { puts; puts "Disconnected #{Time.now}" }
      @sky.on_reconnect { puts "Connection lost, reconnecting..." }
      @sky.on_error { |e| puts "ERROR: #{Time.now} #{e.class} #{e.message}" }
    end

    @sky.connect
  end

  def stop
    @sky&.disconnect
    @sky = nil
  end

  def load_or_init_cursor
    if sub = Subscription.find_by(service: @service)
      sub.cursor
    else
      Subscription.create!(service: @service, cursor: 0)
      nil
    end
  end

  def save_cursor(cursor)
    Subscription.where(service: @service).update_all(cursor: cursor)
  end

  def handle_message(msg)
    if msg.seq % 10 == 0
      save_cursor(msg.seq)
    end

    if @replaying
      puts "Replaying events since #{msg.time.getlocal} -->"
      @replaying = false
    end

    return if msg.type != :commit

    msg.operations.each do |op|
      case op.type
      when :bsky_post
        process_post(msg, op)

      when :bsky_like, :bsky_repost
        # if you want to use the number of likes and/or reposts for filtering or sorting:
        # add a likes/reposts column to feeds, then do +1 / -1 here depending on op.action

      when :bsky_follow
        # if you want to make a personalized feed that needs info about given user's follows/followers:
        # add a followers table, then add/remove records here depending on op.action

      else
        # other types like :bsky_block, :bsky_profile (includes profile edits)
      end
    end
  end

  def process_post(msg, op)
    if op.action == :delete
      if post = Post.find_by(repo: op.repo, rkey: op.rkey)
        post.destroy
      end
    end

    return unless op.action == :create

    begin
      text = op.raw_record['text']

      # tip: if you don't need full record data for debugging, delete the data column in posts
      post = Post.new(
        repo: op.repo,
        time: msg.time,
        text: text,
        rkey: op.rkey,
        data: JSON.generate(op.raw_record),
        record: op.raw_record
      )

      matched = false

      @feeds.each do |feed|
        if feed.post_matches?(post)
          FeedPost.create!(feed_id: feed.feed_id, post: post, time: msg.time) unless !@save_posts
          matched = true
        end
      end

      if @log_posts == :all || @log_posts && matched
        puts
        puts text
      end

      post.save! if @save_posts == :all
    rescue StandardError => e
      puts "Error: #{e}"
      p msg unless @env == :production || e.message == "nesting of 100 is too deep"
    end

    print '.' if @show_progress && @log_posts != :all
  end
end
