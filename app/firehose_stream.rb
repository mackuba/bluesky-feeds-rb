require 'json'
require 'sinatra/activerecord'
require 'skyfall'

require_relative 'config'
require_relative 'models/feed_post'
require_relative 'models/post'
require_relative 'models/subscription'
require_relative 'utils'

class FirehoseStream
  attr_accessor :start_cursor, :show_progress, :log_status, :log_posts, :save_posts, :replay_events

  DEFAULT_JETSTREAM = 'jetstream2.us-east.bsky.network'
  POSTS_BATCH_SIZE = 100

  include Utils

  def initialize(service = nil)
    @env = (ENV['APP_ENV'] || ENV['RACK_ENV'] || :development).to_sym
    @service = service || DEFAULT_JETSTREAM

    @show_progress = (@env == :development) ? true : false
    @log_status = true
    @log_posts = (@env == :development) ? :matching : false
    @save_posts = (@env == :development) ? :all : :matching
    @replay_events = (@env == :development) ? false : true

    @feeds = BlueFactory.all_feeds.select(&:is_updating?)
    @post_queue = []
  end

  def start
    return if @sky

    last_cursor = load_or_init_cursor
    cursor = @replay_events ? (@start_cursor || last_cursor) : nil

    @sky = sky = Skyfall::Jetstream.new(@service, {
      cursor: cursor,

      # we ask Jetstream to only send us post records, since we don't need anything else
      # if you need to process e.g. likes or follows too, update or remove this param
      wanted_collections: ['app.bsky.feed.post'],
    })

    # set your user agent here to identify yourself on the relay
    # @sky.user_agent = "My Feed Server (@my.handle) #{@sky.version_string}"

    @sky.check_heartbeat = true

    @sky.on_message do |m|
      process_message(m)
    end

    if @log_status
      @sky.on_connecting { |u| log "Connecting to #{u}..." }

      @sky.on_connect {
        @replaying = !!(cursor)
        log "Connected ✓"
      }

      @sky.on_disconnect {
        log "Disconnected."
      }

      @sky.on_timeout { log "Trying to reconnect..." }
      @sky.on_reconnect { log "Connection lost, reconnecting..." }
      @sky.on_error { |e| log "ERROR: #{e.class} #{e.message}" }
    end

    @sky.connect
  end

  def stop
    save_queued_posts
    save_cursor(@sky.cursor) unless @sky.nil?

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

  def process_message(msg)
    if msg.type == :info
      # AtProto error, the only one right now is "OutdatedCursor"
      log "InfoMessage: #{msg}"

    elsif msg.type == :identity
      # use these events if you want to track handle changes:
      # log "Handle change: #{msg.repo} => #{msg.handle}"

    elsif msg.type == :account
      # tracking account status changes, e.g. suspensions, deactivations and deletes
      process_account_message(msg)

    elsif msg.is_a?(Skyfall::Firehose::UnknownMessage)
      log "Unknown message type: #{msg.type} (#{msg.seq})"
    end

    return unless msg.type == :commit

    if @replaying
      log "Replaying events since #{msg.time.getlocal} -->"
      @replaying = false
    end

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

  def process_account_message(msg)
    if msg.status == :deleted
      # delete all data we have stored about this account
      FeedPost.joins(:post).where(post: { repo: msg.did }).delete_all
      Post.where(repo: msg.did).delete_all
    end
  end

  def process_post(msg, op)
    if op.action == :delete
      if post = Post.find_by_repo_rkey(op.repo, op.rkey)
        post.destroy
      end
    end

    return unless op.action == :create

    begin
      if op.raw_record.nil?
        log "Error: missing expected record data in operation: #{op.uri} (#{msg.seq})"
        return
      end
    rescue CBOR::UnpackError => e
      log "Error: couldn't decode record data for #{op.uri} (#{msg.seq}): #{e}"
      return
    end

    # ignore posts with past date from Twitter etc. imported using some kind of tool
    begin
      post_time = Time.parse(op.raw_record['createdAt'])
      return if post_time < msg.time - 86400
    rescue StandardError => e
      log "Skipping post with invalid timestamp: #{op.raw_record['createdAt'].inspect} (#{op.repo}, #{msg.seq})"
      return
    end

    text = op.raw_record['text']

    # to save space, delete redundant post text and type from the saved data JSON
    trimmed_record = op.raw_record.dup
    trimmed_record.delete('$type')
    trimmed_record.delete('text')
    trimmed_json = JSON.generate(trimmed_record)

    # tip: if you don't need full record data for debugging, delete the data column in posts
    post = Post.new(
      repo: op.repo,
      time: msg.time,
      text: text,
      rkey: op.rkey,
      data: trimmed_json,
      record: op.raw_record
    )

    if !post.valid?
      if post.errors.has_key?(:data)
        post.trim_too_long_data
      end

      if !post.valid?
        log "Error: post is invalid: #{op.uri} (#{msg.seq}): #{post.errors.to_a.join(', ')}"
        return
      end
    end

    matched = false

    @feeds.each do |feed|
      if feed.post_matches?(post)
        post.feed_posts.build(feed_id: feed.feed_id, time: msg.time) unless !@save_posts
        matched = true
      end
    end

    if @log_posts == :all || @log_posts && matched
      puts
      puts text
    end

    if @save_posts == :all || @save_posts && matched
      @post_queue << post
    end

    # wait until we have 100 posts and then save them all in one insert, if possible
    if @post_queue.length >= POSTS_BATCH_SIZE
      save_queued_posts
      save_cursor(@sky.cursor)
    end

    print '.' if @show_progress && @log_posts != :all
  rescue StandardError => e
    log "Error in #process_post: #{e}"

    unless e.message == "nesting of 100 is too deep"
      log msg.inspect
      log e.backtrace.reject { |x| x.include?('/ruby/') }
    end
  end

  def save_queued_posts
    # we can only squash posts into one insert statement if they don't have nested feed_posts
    # so we save those without feed_posts first:

    matched, unmatched = @post_queue.partition { |x| x.feed_posts.length > 0 }

    if unmatched.length > 0
      values = unmatched.map { |p| p.attributes.except('id') }
      Post.insert_all(values)
    end

    @post_queue = matched
    return if @post_queue.empty?

    # and for those that do have feed_posts, we save them normally, in one transaction:

    ActiveRecord::Base.transaction do
      @post_queue.each do |p|
        # skip validations since we've checked the posts before adding them to the queue
        p.save!(validate: false)
      end
    end

    @post_queue = []
  rescue StandardError => e
    # there shouldn't be any ActiveRecord errors raised, but SQLite might find some issues which
    # aren't covered by AR validations; so in that case, try to save any valid posts one by one:

    @post_queue.each do |p|
      begin
        ActiveRecord::Base.transaction do
          p.save!(validate: false)
        end
      rescue StandardError => e
        log "Error in #save_queued_posts: #{e}"

        unless e.message == "nesting of 100 is too deep"
          log p.inspect
          log e.backtrace.reject { |x| x.include?('/ruby/') }
        end
      end
    end

    @post_queue = []
  end

  def log(text)
    puts if @show_progress
    puts "[#{Time.now}] #{text}"
  end

  def inspect
    vars = instance_variables - [:@feeds, :@timer]
    values = vars.map { |v| "#{v}=#{instance_variable_get(v).inspect}" }.join(", ")
    "#<#{self.class}:0x#{object_id} #{values}>"
  end
end
