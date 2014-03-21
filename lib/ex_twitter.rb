# -*- coding: utf-8 -*-
require 'twitter'
require 'yaml'
require 'active_support'
require 'parallel'

# extended twitter
class ExTwitter < Twitter::REST::Client
  attr_accessor :cache, :cache_expires_in, :max_attempts, :wait

  MAX_ATTEMPTS = 1
  WAIT = false
  CACHE_EXPIRES_IN = 300

  def self.get_config_value(config)
    return {} if config.nil?
    {
      consumer_key: config['consumer_key'],
      consumer_secret: config['consumer_secret'],
      access_token: config['access_token'],
      access_token_secret: config['access_token_secret']
    }
  end

  def initialize(config={})
    if config.empty?
      yml_config = if File.exists?(File.expand_path('./', 'config.yml'))
        YAML.load_file('config.yml')
      elsif File.exists?(File.expand_path('./config/', 'config.yml'))
        YAML.load_file('config/config.yml')
      end
      config = self.class.get_config_value(yml_config)
    end

    self.max_attempts = (config[:max_attempts] || MAX_ATTEMPTS)
    self.wait = (config[:wait] || WAIT)
    self.cache_expires_in = (config[:cache_expires_in] || CACHE_EXPIRES_IN)
    self.cache = ActiveSupport::Cache::FileStore.new(File.join(Dir::pwd, 'ex_twitter_cache'),
      {expires_in: self.cache_expires_in, race_condition_ttl: self.cache_expires_in})
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

  def collect_with_max_id(collection=[], max_id=nil, &block)
    response = yield(max_id)
    return response unless response[1].nil?

    collection += response[0]
    response[0].empty? ? [collection.flatten, nil] : collect_with_max_id(collection, response[0].last.id - 1, &block)
  end

  def collect_with_cursor(collection=[], cursor=-1, &block)
    response = yield(cursor)
    return response unless response[1].nil?

    collection += (response[0][:users] || response[0][:ids])
    next_cursor = response[0][:next_cursor]
    next_cursor == 0 ? [collection.flatten, nil] : collect_with_cursor(collection, next_cursor, &block)
  end

  def get_latest_200_tweets(user=nil)
    num_attempts = 0
    options = {count: 200, include_rts: true}
    begin
      num_attempts += 1
      [user_timeline(user, options), nil]
    rescue Twitter::Error::TooManyRequests => e
      if num_attempts <= MAX_ATTEMPTS
        if WAIT
          sleep e.rate_limit.reset_in
          retry
        else
          puts "retry #{e.rate_limit.reset_in} seconds later"
          [[], e]
        end
      else
        puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS})"
        [[], e]
      end
    rescue => e
      if num_attempts <= MAX_ATTEMPTS
        retry
      else
        puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), something error #{e.inspect}"
        [[], e]
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
        [user_timeline(user, options), nil]
      rescue Twitter::Error::TooManyRequests => e
        if num_attempts <= MAX_ATTEMPTS
          if WAIT
            sleep e.rate_limit.reset_in
            retry
          else
            puts "retry #{e.rate_limit.reset_in} seconds later"
            [[], e]
          end
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS})"
          [[], e]
        end
      rescue => e
        if num_attempts <= MAX_ATTEMPTS
          retry
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), something error #{e.inspect}"
          [[], e]
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
      next [cache, nil] unless cache.nil?
      begin
        num_attempts += 1
        object = friends(user, options)
        self.write(cache_key, object.attrs)
        [object.attrs, nil]
      rescue Twitter::Error::TooManyRequests => e
        if num_attempts <= MAX_ATTEMPTS
          if WAIT
            sleep e.rate_limit.reset_in
            retry
          else
            puts "retry #{e.rate_limit.reset_in} seconds later"
            [{}, e]
          end
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS})"
          [{}, e]
        end
      rescue => e
        if num_attempts <= MAX_ATTEMPTS
          retry
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), something error #{e.inspect}"
          [{}, e]
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
      next [cache, nil] unless cache.nil?
      begin
        num_attempts += 1
        object = followers(user, options)
        self.write(cache_key, object.attrs)
        [object.attrs, nil]
      rescue Twitter::Error::TooManyRequests => e
        if num_attempts <= MAX_ATTEMPTS
          if WAIT
            sleep e.rate_limit.reset_in
            retry
          else
            puts "retry #{e.rate_limit.reset_in} seconds later"
            [{}, e]
          end
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS})"
          [{}, e]
        end
      rescue => e
        if num_attempts <= MAX_ATTEMPTS
          retry
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), something error #{e.inspect}"
          [{}, e]
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
      next [cache, nil] unless cache.nil?
      begin
        num_attempts += 1
        object = friend_ids(user, options)
        self.write(cache_key, object.attrs)
        [object.attrs, nil]
      rescue Twitter::Error::TooManyRequests => e
        if num_attempts <= MAX_ATTEMPTS
          if WAIT
            sleep e.rate_limit.reset_in
            retry
          else
            puts "retry #{e.rate_limit.reset_in} seconds later"
            [{}, e]
          end
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS})"
          [{}, e]
        end
      rescue => e
        if num_attempts <= MAX_ATTEMPTS
          retry
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), something error #{e.inspect}"
          [{}, e]
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
      next [cache, nil] unless cache.nil?
      begin
        num_attempts += 1
        object = follower_ids(user, options)
        self.write(cache_key, object.attrs)
        [object.attrs, nil]
      rescue Twitter::Error::TooManyRequests => e
        if num_attempts <= MAX_ATTEMPTS
          if WAIT
            sleep e.rate_limit.reset_in
            retry
          else
            puts "retry #{e.rate_limit.reset_in} seconds later"
            [{}, e]
          end
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS})"
          [{}, e]
        end
      rescue => e
        if num_attempts <= MAX_ATTEMPTS
          retry
        else
          puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), something error #{e.inspect}"
          [{}, e]
        end
      end
    end
  end

  def get_users(ids)
    ids_per_worker = []
    while(ids.size > 0)
      ids_per_worker << ids.slice!(0, [100, ids.size].min)
    end

    num_attempts = 0
    processed_users = []
    Parallel.each_with_index(ids_per_worker, in_threads: ids_per_worker.size) do |ids, i|
      cache_key = "#{self.class.name}:#{__callee__}:#{i}:#{ids}"
      cache = self.read(cache_key)
      if cache.nil?
        begin
          num_attempts += 1
          object = {i: i, users: users(ids)}
          self.write(cache_key, object)
          processed_users << object
        rescue Twitter::Error::TooManyRequests => e
          if num_attempts <= MAX_ATTEMPTS
            if WAIT
              sleep e.rate_limit.reset_in
              retry
            else
              puts "retry #{e.rate_limit.reset_in} seconds later"
              {i: i, users: [], e: e}
            end
          else
            puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS})"
            {i: i, users: [], e: e}
          end
        rescue => e
          if num_attempts <= MAX_ATTEMPTS
            retry
          else
            puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), something error #{e.inspect}"
            {i: i, users: [], e: e}
          end
        end
      else
        processed_users << cache
      end
    end
    # TODO remove if users have error, or raise
    processed_users.sort_by{|p|p[:i]}.map{|p|p[:users]}.flatten
  end

  # mentions_timeline is to fetch the timeline of Tweets mentioning the authenticated user
  # get_mentions is to fetch the Tweets mentioning the screen_name's user
  def get_mentions(screen_name)
    search_tweets("to:#{screen_name}", {result_type: 'recent', count: 100})
  end

  def search_japanese_tweets(str)
    search_tweets(str, {result_type: 'recent', count: 100, lang: 'ja'})
  end

  def search_tweets_except_rt(str)
    search_tweets("#{str} -rt", {result_type: 'recent', count: 100})
  end

  def search_tweets(str, options)
    num_attempts = 0
    begin
      num_attempts += 1
      result = search(str, options)
      [result.take(100), nil]
    rescue Twitter::Error::TooManyRequests => e
      if num_attempts <= MAX_ATTEMPTS
        if WAIT
          sleep e.rate_limit.reset_in
          retry
        else
          puts "retry #{e.rate_limit.reset_in} seconds later"
          [[], e]
        end
      else
        puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS})"
        [[], e]
      end
    rescue => e
      if num_attempts <= MAX_ATTEMPTS
        retry
      else
        puts "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), something error #{e.inspect}"
        [[], e]
      end
    end
  end
end

if __FILE__ == $0
  puts '--start--'
  client = ExTwitter.new
  puts client.get_all_friends.size
  #followers, error = client.get_all_followers
  #puts "#{followers.size} #{error.inspect}"
  # tweets, error = client.search_japanese_tweets('りんご')
  # tweets, error = client.search_tweets_except_rt('#りんご')
  # puts tweets.size
=begin
  tweets.each do |t|
    next if !t.media?
    puts t.text
    puts t.media[0].attrs
    puts '----'
  end
=end
end


