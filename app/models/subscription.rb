require 'active_record'

class Subscription < ActiveRecord::Base
  validates_presence_of :service, :cursor
end
