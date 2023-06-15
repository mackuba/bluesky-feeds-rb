#!/usr/bin/env ruby

require 'bundler/setup'

require_relative 'app/config'

BlueFactory::Server.set :port, 3000
BlueFactory::Server.run!
