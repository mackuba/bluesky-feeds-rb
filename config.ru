require_relative 'app/config'

# might not be needed depending on the app server you use - comment out these lines to leave logs on STDOUT
Dir.mkdir('log') unless Dir.exist?('log')
log = File.new("log/sinatra.log", "a+")
log.sync = true
use Rack::CommonLogger, log

run BlueFactory::Server
