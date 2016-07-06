twitter-with-auto-pagination
============================

[![Gem Version](https://badge.fury.io/rb/twitter_with_auto_pagination.png)](https://badge.fury.io/rb/twitter_with_auto_pagination)
[![Build Status](https://travis-ci.org/ts-3156/twitter-with-auto-pagination.svg?branch=master)](https://travis-ci.org/ts-3156/twitter-with-auto-pagination)

Add auto pagination, auto caching and parallelly fetching features to Twitter gem.

## Installation

### Gem

```
gem install twitter_with_auto_pagination
```

### Rails

Add `twitter_with_auto_pagination` to your Gemfile, and bundle.

## Features

* Auto pagination
* Auto caching
* Parallelly fetching

## Configuration

You can pass configuration options as a block to `Twitter::REST::Client.new` just like Twitter gem.

```
client = Twitter::REST::Client.new do |config|
  config.consumer_key        = "YOUR_CONSUMER_KEY"
  config.consumer_secret     = "YOUR_CONSUMER_SECRET"
  config.access_token        = "YOUR_ACCESS_TOKEN"
  config.access_token_secret = "YOUR_ACCESS_SECRET"
end
```

## Usage Examples

After configuring a `client`, you can do the following things.

### Pre-existing and enhanced APIs

Fetch the timeline of Tweets (by screen name or user ID, or by implicit authenticated user)

```
client.user_timeline('gem')
client.user_timeline(213747670)
client.user_timeline

result.size
# => 588

result.first.text
# => "Your tweet text..."

result.first.user.screen_name
# => "your_screen_name"
```

Fetch the timeline of Tweets from the authenticated user's home page

```
client.home_timeline
```

Fetch the timeline of Tweets mentioning the authenticated user

```
client.mentions_timeline
```

Fetch all friends's user IDs (by screen name or user ID, or by implicit authenticated user)

```
client.friend_ids('gem')
client.friend_ids(213747670)
client.friend_ids
```

Fetch all followers's user IDs (by screen name or user ID, or by implicit authenticated user)

```
client.follower_ids('gem')
client.follower_ids(213747670)
client.follower_ids
```

Fetch all friends with profile details (by screen name or user ID, or by implicit authenticated user)

```
client.friends('gem')
client.friends(213747670)
client.friends
```

Fetch all followers with profile details (by screen name or user ID, or by implicit authenticated user)

```
client.followers('gem')
client.followers(213747670)
client.followers
```

Other APIs(e.g. `favorites`, `search`) also have auto pagination feature. 

### New APIs

```
client.mutual_friends
```

```
client.one_sided_friends
```

```
client.one_sided_followers
```

```
client.common_friends(me, you)
```

```
client.common_followers(me, you)
```

```
client.close_friends
```

```
client.removing(past_me, cur_me)
```

```
client.removed(past_me, cur_me)
```

```
client.replying
```

```
client.replied
```
