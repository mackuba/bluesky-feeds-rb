require 'bundler/setup'

require 'blue_factory/rake'
require 'sinatra/activerecord'
require 'sinatra/activerecord/rake'

require_relative 'app/config'
require_relative 'app/utils'

def get_feed
  if ENV['KEY'].to_s == ''
    puts "Please specify feed key as KEY=feedname (the part of the feed's at:// URI after the last slash)"
    exit 1
  end

  feed_key = ENV['KEY']
  feed = BlueFactory.get_feed(feed_key)

  if feed.nil?
    puts "No feed configured for key '#{feed_key}' - use `BlueFactory.add_feed '#{feed_key}', MyFeed.new`"
    exit 1
  end

  feed
end

desc "Print posts in the feed, starting from the newest ones (limit = N)"
task :print_feed do
  feed = get_feed
  limit = ENV['N'] ? ENV['N'].to_i : 100

  posts = FeedPost.where(feed_id: feed.feed_id).joins(:post).order('feed_posts.time DESC').limit(limit).map(&:post)

  Rainbow.enabled = true

  # this fixes an error when piping a long output to less and then closing without reading it all
  Signal.trap("SIGPIPE", "SYSTEM_DEFAULT")

  posts.each do |s|
    print Rainbow(s.time).bold + ' * ' + Rainbow(s.id).bold + ' * '
    puts Rainbow("https://bsky.app/profile/#{s.repo}/post/#{s.rkey}").darkgray
    puts
    puts feed.colored_text(s.text)
    if s.record['embed']
      json = JSON.generate(s.record['embed'])
      colored = feed.colored_text(json)
      puts colored unless colored == json
    end
    puts
    puts "---"
    puts
  end
end

desc "Remove a single post from a feed"
task :delete_feed_item do
  feed = get_feed

  if ENV['URL'].to_s == ''
    puts "Please specify post url as URL=https://bsky.app/..."
    exit 1
  end

  url = ENV['URL']
  parts = url.gsub(/^https:\/\//, '').split('/')
  author = parts[2]
  rkey = parts[4]

  if author.start_with?('did:')
    did = author
    handle = Utils.handle_from_did(did)
  else
    handle = author
    did = Utils.did_from_handle(handle)
  end

  if item = FeedPost.joins(:post).find_by(feed_id: feed.feed_id, post: { repo: did, rkey: rkey })
    item.destroy
    puts "Deleted post by @#{handle} from #{feed.display_name} feed"
  else
    puts "Post not found in the feed"
  end
end

desc "Rescan all posts and rebuild the feed from scratch (DAYS = number of days)"
task :rebuild_feed do
  feed = get_feed
  method = ENV['UNSAFE'] ? :tap : :transaction

  ActiveRecord::Base.send(method) do
    if ENV['ONLY_EXISTING']
      feed_posts = FeedPost.where(feed_id: feed.feed_id).includes(:post).to_a
      total = feed_posts.length

      puts "Processing posts..."

      deleted = 0

      feed_posts.each do |fp|
        if !feed.post_matches?(fp.post)
          puts "Deleting from feed: ##{fp.post.id} \"#{fp.post.text}\""
          fp.destroy
          deleted += 1
        end
      end

      puts "Done (#{deleted} post(s) deleted)."
    else
      days = ENV['DAYS'] ? ENV['DAYS'].to_i : 7

      posts = Post.order('time, id')
      start = posts.where("time <= DATETIME('now', '-#{days} day')").last
      stop = posts.last
      first = posts.first
      total = start ? (stop.id - start.id + 1) : (stop.id - first.id + 1)

      if ENV['APPEND_ONLY']
        current_post_ids = FeedPost.where(feed_id: feed.feed_id).pluck('post_id')
      else
        print "This will erase and replace the contents of the feed. Continue? [y/n]: "
        answer = STDIN.readline
        exit unless answer.strip.downcase == 'y'

        puts "Cleaning up feed..."
        FeedPost.where(feed_id: feed.feed_id).delete_all
        current_post_ids = []
      end

      offset = 0
      page = 100000

      loop do
        batch = if start
          posts.where("time > ? OR (time = ? AND id > ?)", start.time, start.time, start.id).limit(page).to_a
        else
          posts.limit(page).to_a
        end

        break if batch.empty?

        batch.each_with_index do |post, i|
          print "Processing posts... [#{offset + i + 1}/#{total}]\r"
          $stdout.flush

          if !current_post_ids.include?(post.id) && feed.post_matches?(post)
            FeedPost.create!(feed_id: feed.feed_id, post: post, time: post.time)
          end
        end

        offset += page
        start = batch.last
      end

      puts "Processing posts... Done." + " " * 30
    end
  end
end

desc "Delete posts older than N days that aren't included in a feed"
task :cleanup_posts do
  days = ENV['DAYS'].to_i
  if days <= 0
    puts "Please specify number of days as e.g. DAYS=30 to delete posts older than that"
    exit 1
  end

  result = ActiveRecord::Base.connection.execute("SELECT DATETIME('now', '-#{days} days') AS time_limit")
  time_limit = result.first['time_limit']

  subquery = %{
    SELECT posts.id FROM posts
    LEFT JOIN feed_posts ON (feed_posts.post_id = posts.id)
    WHERE feed_posts.id IS NULL AND posts.time < DATETIME('now', '-#{days} days')
  }

  result = Post.where("id IN (#{subquery})").delete_all

  puts "Deleted #{result} posts older than #{time_limit}"
end
