# -*- coding: utf-8 -*-
require 'twitter'
require 'yaml'
require 'active_support'

# extended twitter
class ExTwitter < Twitter::REST::Client
  attr_accessor :cache

  def initialize(config={})
    self.cache = ActiveSupport::Cache::FileStore.new(File.join(Dir::pwd, 'ex_twitter_cache'),
      {expires_in: 300, race_condition_ttl: 300})
    super
  end

  def read(key)
    self.cache.read(key)
  rescue => e
    puts "in read #{key} #{e.inspect}"
    nil
  end

  def write(key, value)
    self.cache.write(key, value)
  rescue => e
    puts "in write #{key} #{value} #{e.inspect}"
    false
  end

  MAX_ATTEMPTS = 1
  WAIT = false

  def collect_with_max_id(collection=[], max_id=nil, &block)
    response = yield(max_id)
    collection += response
    response.empty? ? collection.flatten : collect_with_max_id(collection, response.last.id - 1, &block)
  end

  def collect_with_cursor(collection=[], cursor=-1, &block)
    response = yield(cursor)
    collection += (response[:users] || response[:ids])
    next_cursor = response[:next_cursor]
    next_cursor == 0 ? collection.flatten : collect_with_cursor(collection, next_cursor, &block)
  end

  def get_latest_200_tweets(user=nil)
    num_attempts = 0
    options = {count: 200, include_rts: true}
    begin
      num_attempts += 1
      user_timeline(user, options)
    rescue Twitter::Error::TooManyRequests => e
      if num_attempts <= MAX_ATTEMPTS
        if WAIT
          sleep e.rate_limit.reset_in
          retry
        else
          puts "retry #{e.rate_limit.reset_in} minutes later"
          []
        end
      else
        puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS})"
        []
      end
    rescue => e
      if num_attempts <= MAX_ATTEMPTS
        retry
      else
        puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), something error #{e.inspect}"
        []
      end
    end
  end

  def get_all_tweets(user=nil)
    num_attempts = 0
    collect_with_max_id do |max_id|
      options = {count: 200, include_rts: true}
      options[:max_id] = max_id unless max_id.nil?
      begin
        num_attempts += 1
        user_timeline(user, options)
      rescue Twitter::Error::TooManyRequests => e
        if num_attempts <= MAX_ATTEMPTS
          if WAIT
            sleep e.rate_limit.reset_in
            retry
          else
            puts "retry #{e.rate_limit.reset_in} minutes later"
            []
          end
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS})"
          []
        end
      rescue => e
        if num_attempts <= MAX_ATTEMPTS
          retry
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), something error #{e.inspect}"
          []
        end
      end
    end
  end

  def get_all_friends(user=nil)
    num_attempts = 0
    collect_with_cursor do |cursor|
      options = {count: 200, include_user_entities: true}
      options[:cursor] = cursor unless cursor.nil?
      cache_key = "#{self.class.name}:#{__callee__}:#{user}:#{options}"

      cache = self.read(cache_key)
      next cache unless cache.nil?
      begin
        num_attempts += 1
        object = friends(user, options)
        self.write(cache_key, object.attrs)
        object.attrs
      rescue Twitter::Error::TooManyRequests => e
        if num_attempts <= MAX_ATTEMPTS
          if WAIT
            sleep e.rate_limit.reset_in
            retry
          else
            puts "retry #{e.rate_limit.reset_in} minutes later"
            []
          end
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS})"
          []
        end
      rescue => e
        if num_attempts <= MAX_ATTEMPTS
          retry
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), something error #{e.inspect}"
          []
        end
      end
    end
  end

  def get_all_followers(user=nil)
    num_attempts = 0
    collect_with_cursor do |cursor|
      options = {count: 200, include_user_entities: true}
      options[:cursor] = cursor unless cursor.nil?
      cache_key = "#{self.class.name}:#{__callee__}:#{user}:#{options}"

      cache = self.read(cache_key)
      next cache unless cache.nil?
      begin
        num_attempts += 1
        object = followers(user, options)
        self.write(cache_key, object.attrs)
        object.attrs
      rescue Twitter::Error::TooManyRequests => e
        if num_attempts <= MAX_ATTEMPTS
          if WAIT
            sleep e.rate_limit.reset_in
            retry
          else
            puts "retry #{e.rate_limit.reset_in} minutes later"
            []
          end
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS})"
          []
        end
      rescue => e
        if num_attempts <= MAX_ATTEMPTS
          retry
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), something error #{e.inspect}"
          []
        end
      end
    end
  end

  def get_all_friend_ids(user=nil)
    num_attempts = 0
    collect_with_cursor do |cursor|
      options = {count: 5000}
      options[:cursor] = cursor unless cursor.nil?
      cache_key = "#{self.class.name}:#{__callee__}:#{user}:#{options}"

      cache = self.read(cache_key)
      next cache unless cache.nil?
      begin
        num_attempts += 1
        object = friend_ids(user, options)
        self.write(cache_key, object.attrs)
        object.attrs
      rescue Twitter::Error::TooManyRequests => e
        if num_attempts <= MAX_ATTEMPTS
          if WAIT
            sleep e.rate_limit.reset_in
            retry
          else
            puts "retry #{e.rate_limit.reset_in} minutes later"
            []
          end
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS})"
          []
        end
      rescue => e
        if num_attempts <= MAX_ATTEMPTS
          retry
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), something error #{e.inspect}"
          []
        end
      end
    end
  end

  def get_all_follower_ids(user=nil)
    num_attempts = 0
    collect_with_cursor do |cursor|
      options = {count: 5000}
      options[:cursor] = cursor unless cursor.nil?
      cache_key = "#{self.class.name}:#{__callee__}:#{user}:#{options}"

      cache = self.read(cache_key)
      next cache unless cache.nil?
      begin
        num_attempts += 1
        object = follower_ids(user, options)
        self.write(cache_key, object.attrs)
        object.attrs
      rescue Twitter::Error::TooManyRequests => e
        if num_attempts <= MAX_ATTEMPTS
          if WAIT
            sleep e.rate_limit.reset_in
            retry
          else
            puts "retry #{e.rate_limit.reset_in} minutes later"
            []
          end
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS})"
          []
        end
      rescue => e
        if num_attempts <= MAX_ATTEMPTS
          retry
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), something error #{e.inspect}"
          []
        end
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
  client = ExTwitter.new(config)
  #puts client.friends.first.screen_name
  puts "all friends #{client.get_all_friends.size}"
end


