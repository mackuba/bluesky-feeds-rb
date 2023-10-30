require_relative 'feed'

class BuildInPublicFeed < Feed
  REGEXPS = [/\bbuild\s?in\s?public\b/i]

  def feed_id
    3
  end

  def display_name
    "#buildinpublic"
  end

  def description
    "Indie hackers and entrepreneurs building things in public - use #buildinpublic hashtag"
  end

  def post_matches?(post)
    all_text = matched_text(post)

    REGEXPS.any? { |x| all_text =~ x }
  end

  def matched_text(post)
    lines = [post.text]

    if embed = post.record['embed']
      if images = (embed['images'] || embed['media'] && embed['media']['images'])
        lines += images.map { |i| i['alt'] }.compact
      end

      if link = embed['external']
        lines += [link['uri'], link['title'], link['description']].compact
      end
    end

    lines.join("\n")
  end

  def colored_text(t)
    text = t.dup

    REGEXPS.each { |r| text.gsub!(r) { |s| Rainbow(s).green }}

    text
  end
end
