require_relative 'feed'

class KitFeed < Feed
  KIT_REGEX = [/\bkit\b/i]
  CAT_REGEX = [/\bcat\b/i, /\bkitty\b/i]

  PAUL = 'did:plc:ragtjsm2j2vknwkz3zp4oxrd'

  def feed_id
    3
  end

  def display_name
    "Kit Feed"
  end

  def description
    "Photos of Paul's lovely cat Kit 🐱"
  end

  def avatar_file
    "images/kitkat.jpg"
  end

  def post_matches?(post)
    return false unless post.repo == PAUL

    alt = embed_text(post)
    return false if alt.nil?

    KIT_REGEX.any? { |r| alt =~ r } || (CAT_REGEX.any? { |r| alt =~ r } && KIT_REGEX.any? { |r| post.text =~ r })
  end

  def embed_text(post)
    if embed = post.record['embed']
      if images = (embed['images'] || embed['media'] && embed['media']['images'])
        images.map { |i| i['alt'] }.compact.join("\n")
      end
    end
  end

  def colored_text(t)
    text = t.dup

    KIT_REGEX.each { |r| text.gsub!(r) { |s| Rainbow(s).green }}
    CAT_REGEX.each { |r| text.gsub!(r) { |s| Rainbow(s).bright.orange }}

    text
  end
end
