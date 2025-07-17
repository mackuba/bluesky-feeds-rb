require 'bundler/setup'
require 'blue_factory/rake'
require 'sinatra/activerecord'
require 'sinatra/activerecord/rake'

Rake.add_rakelib File.join(__dir__, 'lib', 'tasks')

if ENV['ARLOG'] == '1'
  ActiveRecord::Base.logger = Logger.new(STDOUT)
end
