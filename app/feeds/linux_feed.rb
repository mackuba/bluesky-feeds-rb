require_relative 'feed'

class LinuxFeed < Feed
  def feed_id
    2
  end

  def display_name
    "Linux"
  end

  def description
    "Feed with posts about Linux"
  end

  def avatar_file
    "images/linux_tux.png"
  end

  def post_matches?(post)
    post.text =~ /linux/i
  end
end
