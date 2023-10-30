# TODO: migrate to capistrano3 bundler integration
require 'bundler/capistrano'
set :bundle_dir, ''
set :bundle_flags, '--quiet'
set :bundle_without, []

set :application, "bsky_feeds"
set :repository, "git@github.com:mackuba/bluesky-feeds-rb.git"
set :scm, :git
set :keep_releases, 5
set :use_sudo, false
set :deploy_to, "/var/www/bsky_feeds"
set :deploy_via, :remote_cache
set :migrate_env, "RACK_ENV=production"
set :public_children, []

server "feeds.example.com", :app, :web, :db, :primary => true

before 'bundle:install', 'deploy:set_bundler_options'
after 'deploy:update_code', 'deploy:link_shared'

after 'deploy', 'deploy:cleanup'
after 'deploy:migrations', 'deploy:cleanup'

namespace :deploy do
  task :restart, :roles => :web do
    run "touch #{current_path}/tmp/restart.txt"
  end

  task :set_bundler_options do
    run "cd #{release_path} && bundle config set --local deployment 'true'"
    run "cd #{release_path} && bundle config set --local path '#{shared_path}/bundle'"
    run "cd #{release_path} && bundle config set --local without 'development test'"
  end

  task :link_shared do
    run "ln -s #{shared_path}/bluesky.sqlite3 #{release_path}/db/bluesky.sqlite3"
    run "ln -s #{shared_path}/bluesky.sqlite3-shm #{release_path}/db/bluesky.sqlite3-shm"
    run "ln -s #{shared_path}/bluesky.sqlite3-wal #{release_path}/db/bluesky.sqlite3-wal"
  end
end
