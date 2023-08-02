require 'bundler/setup'

require 'blue_factory/rake'
require 'sinatra/activerecord'
require 'sinatra/activerecord/rake'

require_relative 'app/config'

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

  posts.each do |s|
    puts Rainbow(s.time).bold + ' * ' + Rainbow("https://bsky.app/profile/#{s.repo}/post/#{s.rkey}").darkgray
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

desc "Rescan all posts and rebuild the feed from scratch (DAYS = number of days)"
task :rebuild_feed do
  feed = get_feed

  puts "Cleaning up feed..."
  FeedPost.where(feed_id: feed.feed_id).delete_all

  days = ENV['DAYS'] ? ENV['DAYS'].to_i : 7

  posts = Post.order('time, id').where("time > DATETIME('now', '-#{days} day')")
  total = posts.count

  offset = 0
  page = 100000

  ActiveRecord::Base.transaction do
    while offset < total
      batch = posts.limit(page).offset(offset).to_a

      batch.each_with_index do |post, i|
        print "Processing posts... [#{offset + i + 1}/#{total}]\r"
        $stdout.flush

        if feed.post_matches?(post)
          FeedPost.create!(feed_id: feed.feed_id, post: post, time: post.time)
        end
      end

      offset += page
    end
  end

  puts "Processing posts... Done." + " " * 30
end
