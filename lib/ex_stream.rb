# -*- coding: utf-8 -*-
require 'twitter'
require 'yaml'
require 'active_support'
require 'parallel'

# extended twitter
class ExStream < Twitter::Streaming::Client
  attr_accessor :cache, :cache_expires_in

  MAX_ATTEMPTS = 1
  WAIT = false
  CACHE_EXPIRES_IN = 300

  def initialize(config={})
    self.cache_expires_in = (config[:cache_expires_in] || CACHE_EXPIRES_IN)
    self.cache = ActiveSupport::Cache::FileStore.new(File.join(Dir::pwd, 'ex_twitter_cache'),
      {expires_in: self.cache_expires_in, race_condition_ttl: self.cache_expires_in})
    super
  end

  def print_filter_stream(topics)
    filter(track: topics.join(",")) do |object|
      puts object.text if object.is_a?(Twitter::Tweet)
    end
  end

  def print_sample_stream
    sample do |object|
      puts object.text if object.is_a?(Twitter::Tweet)
    end
  end

  # An object may be one of the following:
  #   Twitter::DirectMessage
  #   Twitter::Streaming::DeletedTweet
  #   Twitter::Streaming::Event
  #   Twitter::Streaming::FriendList
  #   Twitter::Streaming::StallWarning
  #   Twitter::Tweet
  def print_user_stream
    user do |object|
      case object
      when Twitter::Tweet
        puts "It's a tweet!"
      when Twitter::DirectMessage
        puts "It's a direct message!"
      when Twitter::Streaming::StallWarning
        warn "Falling behind!"
      end
    end
  end
end

if __FILE__ == $0
  puts '--start--'
  yml_config = YAML.load_file('config.yml')
  config = {
    consumer_key: yml_config['consumer_key'],
    consumer_secret: yml_config['consumer_secret'],
    access_token: yml_config['access_token'],
    access_token_secret: yml_config['access_token_secret']
  }
  client = ExStream.new(config)
  client.print_sample_stream
end


