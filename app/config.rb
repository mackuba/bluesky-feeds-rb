require_relative 'init'

Dir[File.join(__dir__, 'feeds', '*.rb')].each { |f| require(f) }

BlueFactory.set :publisher_did, 'did:plc:<your_identifier_here>'
BlueFactory.set :hostname, 'feeds.example.com'

# uncomment to enable authentication (note: does not verify signatures)
# see Feed#get_posts(params, visitor_did) in app/feeds/feed.rb
# BlueFactory.set :enable_unsafe_auth, true

BlueFactory.add_feed 'kit', KitFeed.new
BlueFactory.add_feed 'linux', LinuxFeed.new
BlueFactory.add_feed 'starwars', StarWarsFeed.new
