$LOAD_PATH.unshift(File.expand_path('../..', __dir__))

require 'app/config'
require 'app/models/post'


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
