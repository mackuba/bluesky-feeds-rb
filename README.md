<h1>Bluesky feeds in Ruby &nbsp;<img src="https://raw.githubusercontent.com/mackuba/bluesky-feeds-rb/ebbfc3056129a2c31bf030cb21e4b14a71dea3c9/images/ruby.png" width="26"></h1>

This repo is an example or template that you can use to create a "feed generator" service for the Bluesky social network which hosts custom feeds. It's a reimplementation of the official TypeScript [feed-generator](https://github.com/bluesky-social/feed-generator) example in Ruby.

This app is extracted from my personal feed service app running on [blue.mackuba.eu](https://blue.mackuba.eu) which hosts all my custom feeds. My own project has the exact same structure, it just has more feeds, models and stuff in it (and I recently migrated it to Postgres).


## How feed generators work

This is well explained on the Bluesky documentation site, in the section "[Custom Feeds](https://docs.bsky.app/docs/starter-templates/custom-feeds)", and in the readme of the official TypeScript [feed-generator](https://github.com/bluesky-social/feed-generator) project.

The gist is this:

- you (feed operator) run a service on your server, which implements a few specific XRPC endpoints
- a feed record is uploaded to your account, including metadata and location of the feed generator service
- when the user wants to load the feed, the AppView makes a request to your service on their behalf
- your service looks at the request params, and returns a list of posts it selected in the form of at:// URIs
- the AppView takes those URIs and maps them to full posts, which it returns to the user's app

How exactly those posts are selected to be returned in the given request is completely up to you, the only requirement is that these are posts that the AppView will have in its database, since you only send URIs, not actual post data. In most cases, these will be "X latest posts matching some condition". In the request, you get the URI of the specific feed (there can be, and usually is, more than one on the service), `limit`, `cursor`, and an authentication token from which you can extract the DID of the calling user (in case the feed is a personalized one).

It's not a strict requirement, but in order to be able to pick and return those post URIs, in almost all cases the feed service also needs to have a separate component that streams posts from the relay "firehose" and saves some or all of them to a local database.


## Architecture of the app

The project can be divided into three major parts:

1. The "input" part, which subscribes to the firehose stream on the Bluesky relay, reads and processes all incoming messages, and saves relevant posts and any other data to a local database.
2. The "output" part, which makes the list of posts available as a feed server that implements the required "feed generator" endpoints.
3. Everything else in the middle – the database, the models and feed classes.

The first two parts were mostly abstracted away in the forms of two Ruby gems, namely [skyfall](https://github.com/mackuba/skyfall) for connecting to the firehose and [blue_factory](https://github.com/mackuba/blue_factory) for hosting the feed generator interface. See the repositories of these two projects for more info on what they implement and how you can configure and use them.

The part in the middle is mostly up to you, since it depends greatly on what exactly you want to achieve (what kind of feed algorithms to implement, what data you need to keep, what database to use and so on) – but you can use this project as a good starting point.

(The rest of the readme assumes you know Ruby to some degree and are at least somewhat familiar with ActiveRecord.)


### Feeds

The Bluesky API allows you to run feeds using basically any algorithm you want, and there are several main categories of feeds: chronological feeds based on keywords or some simple conditions, "top of the week" feeds sorted by number of likes, or Discover-like feeds with a personalized algorithm and a random-ish order.

The [blue_factory](https://github.com/mackuba/blue_factory) gem used here should allow you to build any kind of feed you want; its main API is a `get_posts` method that you implement in a feed class, which gets request params and returns an array of hashes with post URIs. The decision on how to pick these URIs is up to you.

However, the sample code in this project is mostly targeted at the most common type of feeds, the keyword-based chronological ones. It defines a base feed class [Feed](app/feeds/feed.rb), which includes an implementation of `get_posts` that loads post records from the database, where they have been already assigned earlier to the given feed, so the request handling involves only a very simple query filtered by feed ID. The subclasses of `Feed` provide their versions of a `post_matches?` method, which is used by the firehose client process to determine where a post should be added.

If you want to implement a different kind of feed, e.g. a Following-style feed like my "[Follows & Replies](https://bsky.app/profile/did:plc:oio4hkxaop4ao4wz2pp3f4cr/feed/follows-replies)", that should also be possible with this architecture, but you need to implement a custom version of `get_posts` in a given feed class that does some more complex queries.

The feed classes also include a set of simple getter methods that return metadata about the given feed, like name, description, avatar etc.


### Database & models

By default, the app is configured to use SQLite and to create database files in `db` directory. Using MySQL or PostgreSQL should also be possible with some minor changes in the code (I've tried both) – but SQLite has been working mostly fine for me in production with a database as large as 200+ GB (>200 mln post records). The important thing here is that there's only one "writer" (the firehose process), and the Sinatra server process(es) only read data, so you don't normally run into concurrent write issues, unless you add different unrelated features.

There are two main tables/models: [Post](app/models/post.rb) and [FeedPost](app/models/feed_post.rb). `Post` stores post records as received from the Bluesky relay – the DID of the author, "rkey" of the post record, the post text, and other data as JSON.

`FeedPost` records link specific posts into specific feeds. When a post is saved, the post instance is passed to all configured feed classes, and each of them checks (via `post_matches?`) if the post matches the feed's keywords and if it should be included in that feed. In such case, a matching `FeedPost` is also created. `feed_posts` is kind of like a many-to-many join table, except there is no `feeds` table, it's sort of virtual (feeds are defined in code). `FeedPost` records have a `post_id` referencing a `Post`, and a `feed_id` with the feed number, which is defined in subclasses of the `Feed` class (which is *not* an AR model). Each `Feed` class has one different `feed_id` assigned in code.

The app can be configured to either save every single post, with only some of them having `FeedPost` records referencing them, or to save only the posts which have been added to at least one feed. The mode is selected by using the options `-da` or `-dm` respectively in [`bin/firehose`](bin/firehose). By default, the app uses `-da` (all) mode in development and the `-dm` (matching) mode in production.

Saving all posts allows you to rescan posts when you make changes to a feed and include older posts that were skipped before, but at the cost of storing orders of magnitude more data (around 4 mln posts daily as of July 2025). Saving only matching posts keeps the database much more compact and manageable, but without the ability to re-check missed older posts (or to build feeds using different algorithms than plain keyword matching, e.g. Following-style feeds).

There is an additional `subscriptions` table, which stores the most recent cursor for the relay you're connecting to. This is used when reconnecting after network connection issues or downtime, so you can catch up the missed events added in the meantime since last known position.


### Firehose client

The firehose client service, using the [skyfall](https://github.com/mackuba/skyfall) gem, is implemented in [`app/firehose_stream.rb`](app/firehose_stream.rb). Skyfall handles things like connecting to the websocket and parsing the returned messages; what you need is mostly to provide lifecycle callbacks (which mostly print logs), and to handle the incoming messages by checking the message type and included data.

The most important message type is `:commit`, which includes record operations. For those messages, we check the record type and process the record accordingly – in this case, we're only really looking at post records (`:bsky_post`). For "delete" events we find and delete a `Post` record, for "create" events we build one from the provided data, then pass it through all configured feeds to see if it matches any, then optionally create `FeedPost` references.

All processing here is done inline, single-threaded, within the event processing loop. This should be [more than fine](https://journal.mackuba.eu/2025/06/24/firehose-go-brrr/) in practice even with firehose traffic several times bigger than it is now, as long as you aren't doing (a lot of) network requests within the loop. This could be expanded into a multi-process setup with a Redis queue and multiple workers, but right now there's no need for that.


### XRPC Server

The server implementation is technically in the [blue_factory](https://github.com/mackuba/blue_factory) gem. It's based on [Sinatra](https://sinatrarb.com), and the Sinatra class implementing the 3 required endpoints is included there in [`server.rb`](https://github.com/mackuba/blue_factory/blob/master/lib/blue_factory/server.rb) and can be used as is. It's configured using static methods on the `BlueFactory` module, which is done in [`app/config.rb`](app/config.rb) here.

As an optional thing, the [`app/server.rb`](app/server.rb) file includes some slightly convoluted code that lets you run a block of code in the context of the Sinatra server class, where you can use any normal [Sinatra APIs](https://sinatrarb.com/intro.html) to define additional routes, helpers, change Sinatra configuration, and so on. The example there adds a root `/` endpoint, which returns simple HTML listing available feeds.


## Setting up

This app should run on any somewhat recent version of Ruby, but of course it's recommended to run one that's still maintained, ideally the latest one. It's also recommended to install it with [YJIT support](https://www.leemeichin.com/posts/ruby-32-jit.html), and on Linux also with [jemalloc](https://scalingo.com/blog/improve-ruby-application-memory-jemalloc).

First, you need to install the dependencies of course:

```
bundle install
```

Next, set up the SQLite database. If you want to use e.g. MySQL or PostgreSQL, you need to add a different database adapter gem to the [`Gemfile`](./Gemfile) and change the configuration in [`config/database.yml`](config/database.yml).

To create the database, run the migrations:

```
bundle exec rake db:migrate
```


### Configuration

The feed configuration is done in [`app/config.rb`](app/config.rb). You need to set there:

- the DID identifier of the publisher (your account)
- the hostname on which the service will be running

Next, you need to create some feed classes in [`app/feeds`](app/feeds). See the included feeds like [StarWarsFeed](app/feeds/star_wars_feed.rb) as an example.

Once you have the feeds prepared, configure them in `app/config.rb`:

```rb
BlueFactory.add_feed 'starwars', StarWarsFeed.new
```

The first argument is the "rkey" which will be visible at the end of the feed URL.

If you want to implement some kind of authentication or personalization in your feeds, uncomment the `:enable_unsafe_auth` line in the `config.rb`, and see the commented out alternative implementation of `get_posts` in [`app/feeds/feed.rb`](app/feeds/feed.rb#L68-L99).

(Note: as the "unsafe" part in the name implies, this does not currently fully validate the user tokens – see the "[Authentication](https://github.com/mackuba/blue_factory#authentication)" section in the `blue_factory` readme for more info.)


## Running in development

The app uses two separate processes, for the firehose stream client, and for the XRPC server that handles incoming feed requests.

To run the firehose client, use the [`bin/firehose`](bin/firehose) script. By default, it will save all posts to the database and print progress dots for every saved post, and will print the text of each post that matches any feed's conditions. See the options in the file or in `--help` output to change this.

The app uses one of Bluesky's official [Jetstream](https://github.com/bluesky-social/jetstream) servers as the source by default. If you want to use a different Jetstream server, edit `DEFAULT_JETSTREAM` in [`app/firehose_stream.rb`](app/firehose_stream.rb#L14), or pass a `FIREHOSE=...` env variable on the command line. You can also use a full ATProto relay instead – in that case you will also need to replace the [initializer in the `start` method](app/firehose_stream.rb#L39-L45).

In another terminal window, use the [`bin/server`](bin/server) script to run the server. It should respond to such requests:

```
curl -i http://localhost:3000/.well-known/did.json
curl -i http://localhost:3000/xrpc/app.bsky.feed.describeFeedGenerator
curl -i http://localhost:3000/xrpc/app.bsky.feed.getFeedSkeleton?feed=at://did:plc:.../app.bsky.feed.generator/starwars
```

### Useful Rake tasks

While working on feeds, you may find these two Rake tasks useful:

```
bundle exec rake print_feed KEY=starwars | less -r
```

This task prints the posts included in a feed in a readable format, reverse-chronologically. Optionally, add e.g. `N=500` to include more entries (default is 100).

```
bundle exec rake rebuild_feed ...
```

This task rescans the posts in the database after you edit some feed code, and adds/removes posts to the feed if they now match / no longer match. It has three main modes:

```
bundle exec rake rebuild_feed KEY=starwars DAYS=7
```

- removes all current posts from the feed, scans the given number of days back and re-adds matching posts to the feed

```
bundle exec rake rebuild_feed KEY=starwars DAYS=7 APPEND_ONLY=1
```

- scans the given number of days back and adds additional matching posts to the feed, but without touching existing posts in the feed

```
bundle exec rake rebuild_feed KEY=starwars ONLY_EXISTING=1
```

- quickly checks only posts included currently in the feed, and removes them if needed

There are also `DRY_RUN`, `VERBOSE` and `UNSAFE` env options, see [`feeds.rake`](lib/tasks/feeds.rake) for more info.


## Running in production

In my Ruby projects I'm using the classic [Capistrano](https://capistranorb.com) tool to deploy to production servers (and in the ancient 2.x version, since I still haven't found the time to migrate my setup scripts to 3.x…). There is a sample [`deploy.rb`](config/deploy.rb) config file included in the `config` directory. To use something like Docker or a service like Heroku, you'll need to adapt the config for your specific setup.

On the server, you need to make sure that the firehose process is always running and is restarted if necessary. One option to do this could be writing a systemd service config file and adding it to `/etc/systemd/system`. You can find an example service file in [`dist/bsky_feeds.service`](dist/bsky_feeds.service).

To run the XRPC service, you need an HTTP server (reverse proxy) and a Ruby app server. The choice is up to you and the configuration will depend on your selected config. My recommendation is Nginx with either Passenger (runs your app automatically from Nginx) or something like Puma (needs to be started by e.g. systemd like the firehose). You can find an example of Nginx configuration for Passenger in [`dist/feeds-nginx.conf`](dist/feeds-nginx.conf).


### Publishing the feed

Once you have the feed deployed to the production server, you can use the `bluesky:publish` Rake task (from the [blue_factory](https://github.com/mackuba/blue_factory) gem) to upload the feed configuration to the Bluesky network.

You need to make sure that you have configured the feed's metadata in the feed class:

- `display_name` (required) – the publicly visible name of your feed, e.g. "Star Wars Feed" (should be something short)
- `description` (optional) – a longer (~1-2 lines) description of what the feed does, displayed on the feed page as the "bio"
- `avatar_file` (optional) – path to an avatar image from the project's root (PNG or JPG)

When you're ready, run the rake task passing the feed key (you will be asked for the uploader account's password):

```
bundle exec rake bluesky:publish KEY=starwars
```

If you're on a self-hosted PDS, pass the hostname in a parameter like this: `SERVER_URL=https://pds.example.com`.


### App maintenance

If you're running the app in "save all" mode in production, at some point you will probably need to start cleaning up older posts periodically. You can use this Rake task for this:

```
bundle exec rake cleanup_posts DAYS=30
```

This will delete posts older than 30 days, but only if they aren't assigned to any feed.

Another Rake task lets you remove a specific post manually from a feed – this might be useful e.g. if you notice that something unexpected 🍆 has been included in your feed, and you want to quickly delete it from there without having to edit & redeploy the code:

```
bundle exec rake delete_feed_item URL=https://bsky.app/profile/example.com/post/xxx
```


## Credits

Copyright © 2025 Kuba Suder ([@mackuba.eu](https://bsky.app/profile/mackuba.eu)).

The code is available under the terms of the [zlib license](https://choosealicense.com/licenses/zlib/) (permissive, similar to MIT).

Bug reports and pull requests are welcome 😎
