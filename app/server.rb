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
  end
end
