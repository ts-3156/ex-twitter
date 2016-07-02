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

Add twitter_with_auto_pagination to your Gemfile, and bundle.

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
end
```

## Usage Examples

```
result = client.user_timeline

result.size
# => 588

result.first.text
# => "..."
```

```
result = client.home_timeline
result.size
# => 475
```

```
result = client.friends
result.size
# => 350
```

```
result = client.followers
result.size
# => 928
```
