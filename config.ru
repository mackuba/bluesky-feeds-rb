require_relative 'app/config'
require_relative 'app/server'

# might not be needed depending on the app server you use - comment out these lines to leave logs on STDOUT
Dir.mkdir('log') unless Dir.exist?('log')
$sinatra_log = File.new("log/sinatra.log", "a+")

# flush logs to the file immediately instead of buffering
$sinatra_log.sync = true

# Sinatra turns off its own logging to stdout if another logger is in the stack
use Rack::CommonLogger, $sinatra_log

Server.configure

run BlueFactory::Server
