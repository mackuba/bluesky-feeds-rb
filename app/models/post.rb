require 'active_record'
require 'json'

class Post < ActiveRecord::Base
  validates_presence_of :repo, :time, :data, :rkey
  validates :text, length: { minimum: 0, allow_nil: false }

  attr_writer :record

  def record
    @record ||= JSON.parse(data)
  end
end
