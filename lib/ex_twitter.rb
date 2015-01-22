require 'active_support'
require 'active_support/core_ext'
require 'twitter'
require 'yaml'
require 'active_support'
require 'parallel'
require 'logger'

# extended twitter
class ExTwitter < Twitter::REST::Client
  attr_accessor :cache, :cache_expires_in, :max_attempts, :wait, :auto_paginate, :logger

  MAX_ATTEMPTS = 1
  WAIT = false
  CACHE_EXPIRES_IN = 300
  AUTO_PAGINATE = true
  MAX_CALLS = 3

  def self.get_config_value(config)
    return {} if config.nil?
    {
      consumer_key:        config['consumer_key'],
      consumer_secret:     config['consumer_secret'],
      access_token:        config['access_token'],
      access_token_secret: config['access_token_secret'],
      max_attempts:        config['max_attempts'],
      cache_expires_in:    config['cache_expires_in'],
      auto_paginate:       config['auto_paginate'],
    }
  end

  def initialize(config={})
    self.logger = Logger.new(STDOUT)
    self.logger.level = Logger::DEBUG

    if config.empty?
      yml_config = if File.exists?(File.expand_path('./', 'config.yml'))
        YAML.load_file('config.yml')
      elsif File.exists?(File.expand_path('./config/', 'config.yml'))
        YAML.load_file('config/config.yml')
      end
      config = self.class.get_config_value(yml_config)
    end

    self.auto_paginate = (config[:auto_paginate] || AUTO_PAGINATE)
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
    logger.warn "in read #{key} #{e.inspect}"
    nil
  end

  def write(key, value)
    self.cache.write(key, value)
  rescue => e
    logger.warn "in write #{key} #{value} #{e.inspect}"
    false
  end

  # githubでは、レスポンスが次のエンドポイントを知っているため、ブロックをデータの結合のみに使っている。引数ではAPI名を渡している。
  # 一方、twitterでは、レスポンスが次のエンドポイントを知らないため、ブロック内にAPI名を持ち、再帰的にブロックを呼び出している。
  # また、再帰を使うため、引数をコレクションの引き渡しに使ってしまっている。(この問題については通常のループを使えば解決する)
  #
  # APIは通常繰り返しの呼び出しになるため、API名は常に同じものを保持しておき、ブロックはデータの結合に使った方が無駄がなく自由度が高い。
  # また、再帰ではなく通常のループを使った方が分かりやすい。
  #
  # このgithub方式を実現するためには、メソッド名(例：user_timeline)を渡し、ループさせるか、user_timelineが内部で使っている
  # objects_from_response_with_userをループさせればよい。
  #
  # この2種類の方法を比較した場合、より外側のレイヤーを使った方が、使うライブラリの内部情報に依存しなくなるため、好ましい。
  #
  # twitterで再帰方式がとられている理由は、おそらく、一般ユーザー向けのサンプルでメソッド名を渡すようなリフレクションを避けるため、
  # なのかもしれない。

  # max_idを使って自動ページングを行う
  def collect_with_max_id(method_name, *args, &block)
    options = args.extract_options!
    logger.info "#{method_name}, #{args.inspect} #{options.inspect}"

    max_calls = options.delete(:max_calls) || MAX_CALLS
    data = last_response = send(method_name, *args, options)

    if auto_paginate
      num_attempts = 0
      (max_calls - 1).times do
        break unless last_response.any?

        options[:max_id] = last_response.last.id - 1

        begin
          last_response = send(method_name, *args, options)
          logger.info "#{method_name}, #{args.inspect} #{options.inspect}"
        rescue Twitter::Error::TooManyRequests => e
          if num_attempts <= MAX_ATTEMPTS
            if WAIT
              sleep e.rate_limit.reset_in
              num_attempts += 1
              retry
            else
              logger.warn "retry #{e.rate_limit.reset_in} seconds later, #{e.inspect}"
            end
          else
            logger.warn "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), #{e.inspect}"
          end
        rescue => e
          if num_attempts <= MAX_ATTEMPTS
            logger.warn "retry till num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), #{e.inspect}"
            num_attempts += 1
            retry
          else
            logger.warn "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), something error #{e.inspect}"
          end
        end

        if block_given?
          yield(data, last_response)
        else
          data.concat(last_response) if last_response.is_a?(Array)
        end
      end
    end

    data
  end

  # cursorを使って自動ページングを行う
  def collect_with_cursor(method_name, *args, &block)
    options = args.extract_options!
    logger.info "#{method_name}, #{args.inspect} #{options.inspect}"

    max_calls = options.delete(:max_calls) || MAX_CALLS
    last_response = send(method_name, *args, options).attrs
    data = last_response[:users] || last_response[:ids]

    if auto_paginate
      num_attempts = 0
      (max_calls - 1).times do
        next_cursor = last_response[:next_cursor]
        break if !next_cursor || next_cursor == 0

        options[:cursor] = next_cursor

        begin
          last_response = send(method_name, *args, options).attrs
          logger.info "#{method_name}, #{args.inspect} #{options.inspect}"
        rescue Twitter::Error::TooManyRequests => e
          if num_attempts <= MAX_ATTEMPTS
            if WAIT
              sleep e.rate_limit.reset_in
              num_attempts += 1
              retry
            else
              logger.warn "retry #{e.rate_limit.reset_in} seconds later, #{e.inspect}"
            end
          else
            logger.warn "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), #{e.inspect}"
          end
        rescue => e
          if num_attempts <= MAX_ATTEMPTS
            logger.warn "retry till num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), #{e.inspect}"
            num_attempts += 1
            retry
          else
            logger.warn "fail. num_attempts > MAX_ATTEMPTS(=#{MAX_ATTEMPTS}), something error #{e.inspect}"
          end
        end

        if block_given?
          yield(data, last_response)
        else
          items = last_response[:users] || last_response[:ids]
          data.concat(items) if items.is_a?(Array)
        end
      end
    end

    data
  end

  alias :old_user_timeline :user_timeline
  def user_timeline(*args)
    options = {count: 200, include_rts: true}.merge(args.extract_options!)
    collect_with_max_id(:old_user_timeline, *args, options)
  end

  def user_photos(*args)
    tweets = user_timeline(*args)
    tweets.select{|t| t.media? }.map{|t| t.media }.flatten
  end

  alias :old_friends :friends
  def friends(*args)
    options = {count: 200, include_user_entities: true}.merge(args.extract_options!)
    collect_with_cursor(:old_friends, *args, options)
  end

  alias :old_followers :followers
  def followers(*args)
    options = {count: 200, include_user_entities: true}.merge(args.extract_options!)
    collect_with_cursor(:old_followers, *args, options)
  end

  alias :old_friend_ids :friend_ids
  def friend_ids(*args)
    options = {count: 5000}.merge(args.extract_options!)
    collect_with_cursor(:old_friend_ids, *args, options)
  end

  alias :old_follower_ids :follower_ids
  def follower_ids(*args)
    options = {count: 5000}.merge(args.extract_options!)
    collect_with_cursor(:old_follower_ids, *args, options)
  end

  alias :old_users :users
  def users(ids, options = {})
    ids_per_worker = ids.each_slice(100).to_a
    processed_users = []

    Parallel.each_with_index(ids_per_worker, in_threads: ids_per_worker.size) do |ids, i|
      _users = {i: i, users: old_users(ids, options)}
      processed_users << _users
    end

    processed_users.sort_by{|p| p[:i] }.map{|p| p[:users] }.flatten
  end



  # ここから下は実装できているのか不明

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


