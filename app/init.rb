require 'blue_factory'
require 'sinatra/activerecord'

if defined?(RubyVM::YJIT) && RubyVM::YJIT.respond_to?(:enabled?)
  if !RubyVM::YJIT.enabled?
    if RubyVM::YJIT.respond_to?(:enable)
      # Ruby 3.3+
      RubyVM::YJIT.enable
    else
      # Ruby 3.2
      puts "-" * 106
      puts "Note: YJIT is not enabled. To improve performance, enable it by adding an ENV var RUBYOPT=\"--enable-yjit\"."
      puts "-" * 106
    end
  end
else
  puts "-" * 112
  puts "Note: YJIT is not enabled. To improve performance, it's recommended to " +
    ((RUBY_VERSION.to_f >= 3.2) ? "install Ruby with YJIT support turned on." : "update to a newer Ruby with YJIT support.")
  puts "-" * 112
end

ar_logger = ActiveRecord::Base.logger
ActiveRecord::Base.logger = nil
ActiveRecord::Base.connection.execute "PRAGMA journal_mode = WAL"
ActiveRecord::Base.logger = ar_logger
