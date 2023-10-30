$LOAD_PATH.unshift(File.expand_path('../..', __dir__))

require 'app/config'
require 'app/models/feed_post'
require 'app/models/post'
require 'app/post_console_printer'
require 'app/utils'

require 'base64'
require 'json'
require 'open-uri'


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

def make_jwt(payload)
  header = { typ: 'JWT', alg: 'ES256K' }
  sig = 'fakesig'

  fields = [header, payload].map { |d| Base64.encode64(JSON.generate(d)).chomp } + [sig]
  fields.join('.')
end

desc "Print posts in the feed, starting from the newest ones (limit = N)"
task :print_feed do
  feed = get_feed
  limit = ENV['N'] ? ENV['N'].to_i : 100

  posts = FeedPost.where(feed_id: feed.feed_id).joins(:post).order('feed_posts.time DESC').limit(limit).map(&:post)

  # this fixes an error when piping a long output to less and then closing without reading it all
  Signal.trap("SIGPIPE", "SYSTEM_DEFAULT")

  printer = PostConsolePrinter.new(feed)

  posts.each do |s|
    printer.display(s)
  end
end

desc "Print feed by making an HTTP connection to the XRPC endpoint"
task :test_feed do
  feed = get_feed
  limit = ENV['N'] ? ENV['N'].to_i : 100
  actor = ENV['DID'] || BlueFactory.publisher_did
  jwt = make_jwt({ iss: actor })

  puts "Loading feed..."

  feed_uri = "at://#{BlueFactory.publisher_did}/app.bsky.feed.generator/#{ENV['KEY']}"
  port = ENV['PORT'] || BlueFactory::Server.settings.port
  url = "http://localhost:#{port}/xrpc/app.bsky.feed.getFeedSkeleton?limit=#{limit}&feed=#{feed_uri}"
  headers = { 'Authorization' => "Bearer #{jwt}" }

  json = JSON.parse(URI.open(url, headers).read)
  post_uris = json['feed'].map { |x| x['post'] }

  puts "Loading posts..."

  posts = post_uris.map { |uri| Post.find_by_at_uri(uri) }.compact

  Signal.trap("SIGPIPE", "SYSTEM_DEFAULT")
  printer = PostConsolePrinter.new(feed)

  posts.each do |s|
    printer.display(s)
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
  dry = !!ENV['DRY_RUN']

  ActiveRecord::Base.send(method) do
    if ENV['ONLY_EXISTING']
      rescan_feed_items(feed, dry)
    else
      days = ENV['DAYS'] ? ENV['DAYS'].to_i : 7
      append_only = !!ENV['APPEND_ONLY']

      matched_posts = rebuild_feed(feed, days, append_only, dry)

      if matched_posts && (filename = ENV['TO_FILE'])
        File.write(filename, matched_posts.map(&:id).to_json)
      end
    end
  end
end

def rescan_feed_items(feed, dry = false)
  feed_posts = FeedPost.where(feed_id: feed.feed_id).includes(:post).to_a
  total = feed_posts.length

  puts "Processing posts..."

  deleted = 0

  feed_posts.each do |fp|
    if !feed.post_matches?(fp.post)
      if dry
        puts "Post would be deleted: ##{fp.post.id} \"#{fp.post.text}\""
      else
        puts "Deleting from feed: ##{fp.post.id} \"#{fp.post.text}\""
        fp.destroy
      end
      deleted += 1
    end
  end

  if dry
    puts "#{deleted} post(s) would be deleted."
  else
    puts "Done (#{deleted} post(s) deleted)."
  end
end

def rebuild_feed(feed, days, append_only, dry = false)
  posts = Post.order('time, id')
  start = posts.where("time <= DATETIME('now', '-#{days} days')").last
  stop = posts.last
  first = posts.first
  total = start ? (stop.id - start.id + 1) : (stop.id - first.id + 1)

  if append_only
    current_post_ids = FeedPost.where(feed_id: feed.feed_id).pluck('post_id')
  elsif !dry
    print "This will erase and replace the contents of the feed. Continue? [y/n]: "
    answer = STDIN.readline
    exit unless answer.strip.downcase == 'y'

    puts "Cleaning up feed..."
    FeedPost.where(feed_id: feed.feed_id).delete_all
    current_post_ids = []
  end

  offset = 0
  page = 100000
  matched_posts = []

  loop do
    batch = if start
      posts.where("time > ? OR (time = ? AND id > ?)", start.time, start.time, start.id).limit(page).to_a
    else
      posts.limit(page).to_a
    end

    break if batch.empty?

    batch.each_with_index do |post, i|
      $stderr.print "Processing posts... [#{offset + i + 1}/#{total}]\r"
      $stderr.flush

      if !current_post_ids.include?(post.id) && feed.post_matches?(post)
        if dry
          matched_posts << post
        else
          FeedPost.create!(feed_id: feed.feed_id, post: post, time: post.time)
        end
      end
    end

    offset += page
    start = batch.last
  end

  $stderr.puts "Processing posts... Done." + " " * 30

  if dry
    if append_only
      puts "Added posts:"
      puts "=============================="
      puts
    end

    Signal.trap("SIGPIPE", "SYSTEM_DEFAULT")
    printer = PostConsolePrinter.new(feed)

    matched_posts.each do |p|
      printer.display(p)
    end

    matched_posts
  end
end
