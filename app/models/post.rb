require 'active_record'
require 'json'

class Post < ActiveRecord::Base
  validates_presence_of :repo, :time, :data, :rkey
  validates :text, length: { minimum: 0, allow_nil: false }
  validates_length_of :repo, maximum: 60
  validates_length_of :rkey, maximum: 16
  validates_length_of :text, maximum: 1000
  validates_length_of :data, maximum: 10000

  has_many :feed_posts, dependent: :destroy

  attr_writer :record

  def self.find_by_repo_rkey(repo, rkey)
    # the '+' is to make sure that SQLite uses the rkey index and not a different one
    Post.where("+repo = ?", repo).where(rkey: rkey).first
  end

  def self.find_by_at_uri(uri)
    parts = uri.gsub(%r(^at://), '').split('/')
    return nil unless parts.length == 3 && parts[1] == 'app.bsky.feed.post'

    find_by_repo_rkey(parts[0], parts[2])
  end

  def record
    @record ||= JSON.parse(data)
  end

  def at_uri
    "at://#{repo}/app.bsky.feed.post/#{rkey}"
  end

  def trim_too_long_data
    if embed = record['embed']
      if external = embed['external']
        external['description'] = ''
      end
    end

    if record['bridgyOriginalText']
      record['bridgyOriginalText'] = ''
    end

    self.data = JSON.generate(record)
  end
end
