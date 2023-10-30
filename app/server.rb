require 'blue_factory'

module Server
  def self.configure
    self.instance_method(:run).bind_call(BlueFactory::Server)
  end

  def run
    # do any additional config & customization on BlueFactory::Server here
    # see Sinatra docs for more info: https://sinatrarb.com/intro.html
    # e.g.:
    #
    # disable :logging
    # enable :static
    # set :views, File.expand_path('views', __dir__)
    # set :default_encoding, 'cp1250'
    #
    # before do
    #   headers "X-Powered-By" => "BlueFactory/#{BlueFactory::VERSION}"
    # end
    #
    # get '/' do
    #   erb :index
    # end

    get '/' do
      content_type 'text/html'

      html = %(
        <style>
          body { width: 960px; margin: 40px auto; } li { margin: 5px 0px; }
          a { text-decoration: none; color: #00e; } a:hover { text-decoration: underline; } a:visited { color: #00e; }
        </style>
        <h2>Bluesky Feed Server at #{request.host}</h2>
        <p>This is an AT Protocol XRPC service hosting a Bluesky custom feed generator.</p>
        <p>Available feeds:</p>
        <ul>
      )

      BlueFactory.feed_keys.each do |k|
        feed = BlueFactory.get_feed(k)
        title = feed.display_name
        html << %(<li><a href="https://bsky.app/profile/#{BlueFactory.publisher_did}/feed/#{k}">#{title}</a></li>\n)
      end

      html << %(
        </ul>
        <p>Powered by Ruby and <a href="https://github.com/mackuba/blue_factory">BlueFactory</a>.</p>
      )

      html
    end
  end
end
