require_relative 'app/config'

Dir.mkdir('log') unless Dir.exist?('log')

log = File.new("log/sinatra.log", "a+")
log.sync = true

use Rack::CommonLogger, log

run BlueFactory::Server
