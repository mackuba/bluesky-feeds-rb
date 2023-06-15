require 'active_record'
require_relative 'post'

class FeedPost < ActiveRecord::Base
  belongs_to :post
  validates_presence_of :feed_id, :time
end
