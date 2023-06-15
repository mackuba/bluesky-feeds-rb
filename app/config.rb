Dir[File.join(__dir__, 'feeds', '*.rb')].each { |f| require(f) }

require 'blue_factory'
require 'sinatra/activerecord'

BlueFactory.set :publisher_did, 'did:plc:<your_identifier_here>'
BlueFactory.set :hostname, 'feeds.example.com'

BlueFactory.add_feed 'linux', LinuxFeed.new
BlueFactory.add_feed 'starwars', StarWarsFeed.new
