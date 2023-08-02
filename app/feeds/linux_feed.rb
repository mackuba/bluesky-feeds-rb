require_relative 'feed'

class LinuxFeed < Feed
  REGEXPS = [
    /linux/i, /debian/i, /ubuntu/i, /\bKDE\b/, /\bGTK\d?\b/
  ]

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
    REGEXPS.any? { |r| post.text =~ r }
  end

  def colored_text(t)
    text = t.dup

    REGEXPS.each { |r| text.gsub!(r) { |s| Rainbow(s).green }}

    text
  end
end
