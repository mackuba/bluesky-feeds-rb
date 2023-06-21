<h1>Bluesky feeds in Ruby <img src="https://github.com/mackuba/bluesky-feeds-rb/assets/28465/81159f5a-82f6-4520-82c1-434057905a2c" style="width: 28px; margin-left: 5px; position: relative; top: 1px;"></h1>

This repo is an example or template that you can use to create a "feed generator" service for the Bluesky social network that hosts custom feeds. It's a reimplementation of the official TypeScript [feed-generator](https://github.com/bluesky-social/feed-generator) example in Ruby.


## How do feed generators work

**\#TODO** - please read the README of the official [feed-generator](https://github.com/bluesky-social/feed-generator) project.


## Architecture of the app

The project can be divided into three major parts:

1. The "input" part, which subscribes to the firehose stream on the Bluesky server, reads and processes all incoming messages, and saves relevant posts and any other data to a local database.
2. The "output" part, which makes the list of posts available as a feed server that implements the required "feed generator" endpoints.
3. Everything else in the middle - the database, the models and feed classes.

The first two parts were mostly abstracted away in the forms of two Ruby gems, namely [skyfall](https://github.com/mackuba/skyfall) for connecting to the firehose and [blue_factory](https://github.com/mackuba/blue_factory) for hosting the feed generator interface. The part in the middle is mostly up to you, since it depends greatly on what exactly you want to achieve (what kind of feed algorithms to implement, what data you need to keep, what database to use and so on) - but you can use this project as a good starting point.

See the repositories of these two projects for more info on what they implement and how you can configure and use them.


## Setting up

First, you need to set up the database. By default, the app is configured to use SQLite and to create database files in `db` directory. If you want to use e.g. MySQL or PostgreSQL, you need to add a different database adapter gem to the [`Gemfile`](https://github.com/mackuba/bluesky-feeds-rb/blob/master/Gemfile) and change the configuration in [`config/database.yml`](https://github.com/mackuba/bluesky-feeds-rb/blob/master/config/database.yml).

To create the database, run the migrations:

```
bundle exec rake db:migrate
```

The feed configuration is done in [`app/config.rb`](https://github.com/mackuba/bluesky-feeds-rb/blob/master/app/config.rb). You need to set there:

- the DID identifier of the publisher (your account)
- the hostname on which the service will be running

Next, you need to create some feed classes in [`app/feeds`](https://github.com/mackuba/bluesky-feeds-rb/tree/master/app/feeds). See the included feeds like [`StarWarsFeed`](https://github.com/mackuba/bluesky-feeds-rb/blob/master/app/feeds/star_wars_feed.rb) as an example. The [`Feed`](https://github.com/mackuba/bluesky-feeds-rb/blob/master/app/feeds/feed.rb) superclass provides a `#get_posts` implementation which loads the posts in a feed in response to a request and passes the URIs to the server.

Once you have the feeds prepared, configure them in `app/config.rb`:

```rb
BlueFactory.add_feed 'starwars', StarWarsFeed.new
```


### Running in development

To run the firehose stream, use the [`firehose.rb`](https://github.com/mackuba/bluesky-feeds-rb/tree/master/firehose.rb) script. By default, it will save all posts to the database and print progress dots for every saved post, and will print the text of each post that matches any feed's conditions. See the options in the file to change this.

In another terminal window, use the [`server.rb`](https://github.com/mackuba/bluesky-feeds-rb/tree/master/server.rb) script to run the server. It should respond to such requests:

```
curl -i http://localhost:3000/.well-known/did.json
curl -i http://localhost:3000/xrpc/app.bsky.feed.describeFeedGenerator
curl -i http://localhost:3000/xrpc/app.bsky.feed.getFeedSkeleton?feed=at://did:plc:.../app.bsky.feed.generator/starwars
```

### Running in production

First, you need to make sure that the firehose script is always running and is restarted if necessary. One option to do this could be writing a `systemd` service config file and adding it to `/etc/systemd/system`. You can find an example service file in [`dist/bsky_feeds.service`](https://github.com/mackuba/bluesky-feeds-rb/blob/master/dist/bsky_feeds.service).

To run the server part, you need an HTTP server and a Ruby app server. The choice is up to you and the configuration will depend on your selected config. My recommendation is Nginx with either Passenger (runs your app automatically from Nginx) or something like Puma (needs to be started by e.g. `systemd` like the firehose). You can find an example of Nginx configuration for Passenger in [`dist/feeds-nginx.conf`](https://github.com/mackuba/bluesky-feeds-rb/blob/master/dist/feeds-nginx.conf).


## Publishing the feed

Once you have the feed deployed to the production server, you can use the `bluesky:publish` Rake task (from the [blue_factory](https://github.com/mackuba/blue_factory) gem) to upload the feed configuration to the Bluesky network.

You need to make sure that you have configured the feed's metadata in the feed class:

- `display_name` (required) - the publicly visible name of your feed, e.g. "Star Wars Feed" (should be something short)
- `description` (optional) - a longer (~1-2 lines) description of what the feed does, displayed on the feed page as the "bio"
- `avatar_file` (optional) - path to an avatar image from the project's root (PNG or JPG)

When you're ready, run the rake task passing the feed key (you will be asked for the uploader account's password):

```
bundle exec rake bluesky:publish KEY=starwars
```


## Credits

Copyright © 2023 Kuba Suder ([@mackuba.eu](https://bsky.app/profile/mackuba.eu)).

The code is available under the terms of the [zlib license](https://choosealicense.com/licenses/zlib/) (permissive, similar to MIT).

Bug reports and pull requests are welcome 😎
