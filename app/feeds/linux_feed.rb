require_relative 'feed'

class LinuxFeed < Feed
  REGEXPS = [
    /linux/i, /debian/i, /ubuntu/i, /\bredhat\b/i, /\bRHEL\b/, /\bSUSE\b/, /\bCentOS\b/, /\bopensuse\b/i,
    /\bslackware\b/i, /\bKDE\b/, /\bGTK\d?\b/, /#GNOME\b/, /\bGNOME\s?\d+/, /\bkde plasma\b/i,
    /apt\-get/, /\bflatpak\b/i, /\b[Xx]org\b/
  ]

  EXCLUDE = [
    /\bmastos?\b/i, /mast[oa]d[oa]n/i, /\bfederat(ion|ed)\b/i, /fediverse/i, /at\s?protocol/i,
    /social (media|networks?)/i, /microblogging/i, /\bthreads\b/i, /\bnostr\b/i,
    /the linux of/i, /linux (bros|nerds)/i, /ubuntu tv/i
  ]

  MUTED_PROFILES = [
    'did:plc:35c6qworuvguvwnpjwfq3b5p',  # Linux Kernel Releases
    'did:plc:ppuqidjyabv5iwzeoxt4fq5o',  # GitHub Trending JS/TS
    'did:plc:eidn2o5kwuaqcss7zo7ivye5',  # GitHub Trending
    'did:plc:lontmsdex36tfjyxjlznnea7',  # RustTrending
    'did:plc:myutg2pwkjbukv7pq2hp5mtl',  # CVE Alerts
  ]

  def feed_id
    2
  end

  def display_name
    "Linux"
  end

  def description
    "All posts on Bluesky about Linux and its popular distributions & desktop environments"
  end

  def avatar_file
    "images/linux_tux.png"
  end

  def post_matches?(post)
    return false if MUTED_PROFILES.include?(post.repo)

    REGEXPS.any? { |r| post.text =~ r } && !(EXCLUDE.any? { |r| post.text =~ r })
  end

  def colored_text(t)
    text = t.dup

    EXCLUDE.each { |r| text.gsub!(r) { |s| Rainbow(s).red }}
    REGEXPS.each { |r| text.gsub!(r) { |s| Rainbow(s).green }}

    text
  end
end
