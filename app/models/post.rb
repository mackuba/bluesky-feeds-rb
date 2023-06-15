require 'active_record'

class Post < ActiveRecord::Base
  validates_presence_of :repo, :time, :data, :rkey
  validates :text, length: { minimum: 0, allow_nil: false }
end
