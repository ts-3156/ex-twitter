twitter-with-auto-pagination
============================

[![Gem Version](https://badge.fury.io/rb/ex_twitter.png)](https://badge.fury.io/rb/twitter_with_auto_pagination)
[![Build Status](https://travis-ci.org/ts-3156/ex-twitter.svg?branch=master)](https://travis-ci.org/ts-3156/twitter-with-auto-pagination)

Add auto paginate feature to Twitter gem.

## Installation

### Gem

```
gem install twitter_with_auto_pagination
```

### Rails

Add `twitter_with_auto_pagination` to your Gemfile, and bundle.

## Features

* Auto paginate feature

## Configuration

You can pass configuration options as a block to `TwitterWithAutoPagination::Client.new` just like `Twitter::REST::Client.new`.

```
client = TwitterWithAutoPagination::Client.new do |config|
  config.consumer_key        = "YOUR_CONSUMER_KEY"
  config.consumer_secret     = "YOUR_CONSUMER_SECRET"
  config.access_token        = "YOUR_ACCESS_TOKEN"
  config.access_token_secret = "YOUR_ACCESS_SECRET"
  config.log_level           = :debug             # optional
  config.logger              = Logger.new(STDOUT) # optional
end
```

## Usage Examples

### Existing API

```
tweets = client.user_timeline

tweets.size
# => 588

tweet = tweets.first
tweet.text
# => "Your Tweet..."

tweet.user.screen_name
# => "your_screen_name"
```

```
tweets = client.home_timeline
tweets.size
# => 475
```

```
tweets = client.mentions_timeline
tweets.size
# => xxx
```

```
friend_ids = client.friend_ids
friend_ids.size
# => 350
```

```
follower_ids = client.follower_ids
follower_ids.size
# => 928
```

```
friends = client.friends
friends.size
# => 350
```

```
followers = client.followers
followers.size
# => 928
```

```
tweets = client.favorites
favorites.size
# => xxx
```

```
tweets = client.search('twitter')
tweets.size
# => xxx
```

```
users = client.users(['screen_name_1', 'sn_2', 'sn_3'])
users.size
# => 3
```

### New API

```
mutual_friends = client.mutual_friends
mutual_friends.size
# => xxx
```

```
one_sided_friends = client.one_sided_friends
one_sided_friends.size
# => xxx
```

```
one_sided_followers = client.one_sided_followers
one_sided_followers.size
# => xxx
```

Users which authorized user removed.

```
users = client.removed(pre_me, cur_me)
users.size
# => xxx
```

Users which authorized user is removed by.

```
users = client.removed_by(pre_me, cur_me)
users.size
# => xxx
```
