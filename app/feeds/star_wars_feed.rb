require_relative 'feed'

class StarWarsFeed < Feed
  REGEXPS = [
    /star ?wars/i, /mandalorian/i, /\bandor\b/i, /boba fett/i, /obi[ \-]?wan/i, /\bahsoka\b/, /\bjedi\b/i,
    /\bsith\b/i, /\byoda\b/i, /Empire Strikes Back/, /chewbacca/i, /Han Solo/, /darth vader/i, /skywalker/i,
    /lightsab(er|re)/i, /clone wars/i
  ]

  def feed_id
    1
  end

  def display_name
    "Star Wars"
  end

  def description
    "Feed with posts about Star Wars"
  end

  def avatar_file
    "images/babyyoda.jpg"
  end

  def post_matches?(post)
    REGEXPS.any? { |r| post.text =~ r }
  end
end
