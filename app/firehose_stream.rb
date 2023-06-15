require 'json'
require 'sinatra/activerecord'
require 'skyfall'

require_relative 'config'
require_relative 'models/feed_post'
require_relative 'models/post'

class FirehoseStream
  attr_accessor :show_progress, :log_status, :log_posts, :save_posts

  def initialize
    @env = (ENV['APP_ENV'] || ENV['RACK_ENV'] || :development).to_sym

    @show_progress = (@env == :development) ? true : false
    @log_status = true
    @log_posts = (@env == :development) ? :matching : false
    @save_posts = (@env == :development) ? :all : :matching

    @feeds = BlueFactory.all_feeds
  end

  def start
    return if @sky

    @sky = Skyfall::Stream.new('bsky.social', :subscribe_repos)

    @sky.on_message do |m|
      handle_message(m)
    end

    if @log_status
      @sky.on_connect { puts "Connected #{Time.now} ✓" }
      @sky.on_disconnect { puts; puts "Disconnected #{Time.now}" }
      @sky.on_reconnect { puts "Reconnecting..." }
      @sky.on_error { |e| puts "ERROR: #{Time.now} #{e}" }
    end

    @sky.connect
  end

  def stop
    @sky&.disconnect
    @sky = nil
  end

  def handle_message(msg)
    return if msg.type != :commit

    msg.operations.each do |op|
      return unless op.type == :bsky_post

      if op.action == :delete
        if post = Post.find_by(repo: op.repo, rkey: op.rkey)
          post.destroy
        end
      end

      return unless op.action == :create

      begin
        text = op.raw_record['text']
        post = Post.new(
          repo: op.repo,
          time: msg.time,
          text: text,
          rkey: op.rkey,
          data: JSON.generate(op.raw_record)
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
end
