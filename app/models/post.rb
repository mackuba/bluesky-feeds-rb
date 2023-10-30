require 'active_record'
require 'json'

class Post < ActiveRecord::Base
  validates_presence_of :repo, :time, :data, :rkey
  validates :text, length: { minimum: 0, allow_nil: false }

  has_many :feed_posts, dependent: :destroy

  attr_writer :record

  def self.find_by_at_uri(uri)
    parts = uri.gsub(%r(^at://), '').split('/')
    return nil unless parts.length == 3 && parts[1] == 'app.bsky.feed.post'

    Post.find_by(repo: parts[0], rkey: parts[2])
  end

  def record
    @record ||= JSON.parse(data)
  end

  def at_uri
    "at://#{repo}/app.bsky.feed.post/#{rkey}"
  end
end
