#!/usr/bin/env ruby

require 'bundler/setup'

require_relative 'app/config'
require_relative 'app/server'

Server.configure

BlueFactory::Server.set :port, 3000
BlueFactory::Server.run!
