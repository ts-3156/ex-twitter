ex-twitter
==========

[![Gem Version](https://badge.fury.io/rb/ex_twitter.png)](https://badge.fury.io/rb/ex_twitter)
[![Build Status](https://travis-ci.org/ts-3156/ex-twitter.svg?branch=master)](https://travis-ci.org/ts-3156/ex-twitter)

A Ruby wrapper to the Twitter gem.

## Installation

### Gem

```
gem install ex_twitter
```

### Rails

Add ex_twitter to your Gemfile, and bundle.

## Features

This gem is a thin wrapper of Twitter gem.  
Twitter gem has twitter API like methods.  
This gem has high functionality methods and don't raise exceptions.

## Examples

```
require 'ex_twitter'
client = ExTwitter.new(config)

# get all tweets
client.get_all_tweets

# get all friend ids
client.get_all_friends_ids

# get all friends in parallel
client.get_users(friend_ids)
```

