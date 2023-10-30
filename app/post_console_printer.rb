require 'json'
require 'rainbow'

class PostConsolePrinter
  def initialize(feed)
    @feed = feed
    Rainbow.enabled = true
  end

  def display(post)
    print Rainbow(post.time).bold + ' * ' + Rainbow(post.id).bold + ' * '
    puts Rainbow("https://bsky.app/profile/#{post.repo}/post/#{post.rkey}").darkgray
    puts
    puts @feed.colored_text(post.text)
    if post.record['embed']
      json = JSON.generate(post.record['embed'])
      colored = @feed.colored_text(json)
      puts colored unless colored == json
    end
    puts
    puts "---"
    puts
  end
end
