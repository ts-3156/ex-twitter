ex-twitter
==========

[![Gem Version](https://badge.fury.io/rb/ex_twitter.png)](https://badge.fury.io/rb/ex_twitter)
[![Build Status](https://travis-ci.org/ts-3156/ex-twitter.svg?branch=master)](https://travis-ci.org/ts-3156/ex-twitter)

Add auto paginate feature to Twitter gem.

## Installation

### Gem

```
gem install ex_twitter
```

### Rails

Add ex_twitter to your Gemfile, and bundle.

## Features

* Auto paginate feature

## Configuration

You can pass configuration options as a block to `ExTwitter.new` just like `Twitter::REST::Client.new`.

```
client = ExTwitter.new do |config|
  config.consumer_key        = "YOUR_CONSUMER_KEY"
  config.consumer_secret     = "YOUR_CONSUMER_SECRET"
  config.access_token        = "YOUR_ACCESS_TOKEN"
  config.access_token_secret = "YOUR_ACCESS_SECRET"
end
```

You can pass advanced configuration options as a block to `ExTwitter.new`.

```
client = ExTwitter.new do |config|
  config.auto_paginate = true
  config.max_retries   = 1
  config.max_paginates = 3
end
```

## Usage Examples

```
client.user_timeline
```

