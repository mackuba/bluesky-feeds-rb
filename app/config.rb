Dir[File.join(__dir__, 'feeds', '*.rb')].each { |f| require(f) }

require 'blue_factory'
require 'sinatra/activerecord'

BlueFactory.set :publisher_did, 'did:plc:<your_identifier_here>'
BlueFactory.set :hostname, 'feeds.example.com'

BlueFactory.add_feed 'linux', LinuxFeed.new
BlueFactory.add_feed 'starwars', StarWarsFeed.new

# do any additional config & customization on BlueFactory::Server here:
#
# BlueFactory::Server.disable :logging
# BlueFactory::Server.set :port, 4000
#
# BlueFactory::Server.get '/' do
#   redirect 'https://web.example.com'
# end
#
# BlueFactory::Server.before do
#   headers "X-Powered-By" => "BlueFactory/#{BlueFactory::VERSION}"
# end
