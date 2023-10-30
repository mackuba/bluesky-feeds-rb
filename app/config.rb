Dir[File.join(__dir__, 'feeds', '*.rb')].each { |f| require(f) }

require 'blue_factory'
require 'sinatra/activerecord'

require_relative 'server'

ActiveRecord::Base.connection.execute "PRAGMA journal_mode = WAL"

BlueFactory.set :publisher_did, 'did:plc:<your_identifier_here>'
BlueFactory.set :hostname, 'feeds.example.com'

BlueFactory.add_feed 'build', BuildInPublicFeed.new
BlueFactory.add_feed 'linux', LinuxFeed.new
BlueFactory.add_feed 'starwars', StarWarsFeed.new

Server.configure
