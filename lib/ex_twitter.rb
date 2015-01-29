require 'active_support'
require 'active_support/core_ext'
require 'twitter'
require 'yaml'
require 'active_support'
require 'parallel'
require 'logger'

# extended twitter
class ExTwitter < Twitter::REST::Client
  attr_accessor :cache, :cache_expires_in, :max_retries, :wait, :auto_paginate, :max_paginates, :logger

  MAX_RETRIES = 1
  WAIT = false
  # CACHE_EXPIRES_IN = 300
  AUTO_PAGINATE = true
  MAX_PAGINATES = 3

  def initialize(options = {})
    self.logger = Logger.new(STDOUT)
    self.logger.level = Logger::DEBUG

    self.auto_paginate = AUTO_PAGINATE
    self.max_retries = MAX_RETRIES
    self.wait = WAIT
    self.max_paginates = MAX_PAGINATES

    # self.cache_expires_in = (config[:cache_expires_in] || CACHE_EXPIRES_IN)
    # self.cache = ActiveSupport::Cache::FileStore.new(File.join(Dir::pwd, 'ex_twitter_cache'),
    #   {expires_in: self.cache_expires_in, race_condition_ttl: self.cache_expires_in})

    super
  end

  # def read(key)
  #   self.cache.read(key)
  # rescue => e
  #   logger.warn "in read #{key} #{e.inspect}"
  #   nil
  # end
  #
  # def write(key, value)
  #   self.cache.write(key, value)
  # rescue => e
  #   logger.warn "in write #{key} #{value} #{e.inspect}"
  #   false
  # end

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

    max_paginates = options.delete(:max_paginates) || MAX_PAGINATES
    data = []
    last_response = send(method_name, *args, options)
    if block_given?
      last_response = yield(data, last_response)
    else
      data.concat(last_response) if last_response.is_a?(Array)
    end

    if auto_paginate
      num_retries = 0
      (max_paginates - 1).times do
        break if last_response.blank?

        options[:max_id] = last_response.last[:id] - 1

        begin
          last_response = send(method_name, *args, options)
          logger.info "#{method_name}, #{args.inspect} #{options.inspect}"
        rescue Twitter::Error::TooManyRequests => e
          if num_retries <= MAX_RETRIES
            if WAIT
              sleep e.rate_limit.reset_in
              num_retries += 1
              retry
            else
              logger.warn "retry #{e.rate_limit.reset_in} seconds later, #{e.inspect}"
            end
          else
            logger.warn "fail. num_retries > MAX_RETRIES(=#{MAX_RETRIES}), #{e.inspect}"
          end
        rescue => e
          if num_retries <= MAX_RETRIES
            logger.warn "retry till num_retries > MAX_RETRIES(=#{MAX_RETRIES}), #{e.inspect}"
            num_retries += 1
            retry
          else
            logger.warn "fail. num_retries > MAX_RETRIES(=#{MAX_RETRIES}), something error #{e.inspect}"
          end
        end

        if block_given?
          last_response = yield(data, last_response)
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

    max_paginates = options.delete(:max_paginates) || MAX_PAGINATES
    last_response = send(method_name, *args, options).attrs
    data = last_response[:users] || last_response[:ids]

    if auto_paginate
      num_retries = 0
      (max_paginates - 1).times do
        next_cursor = last_response[:next_cursor]
        break if !next_cursor || next_cursor == 0

        options[:cursor] = next_cursor

        begin
          last_response = send(method_name, *args, options).attrs
          logger.info "#{method_name}, #{args.inspect} #{options.inspect}"
        rescue Twitter::Error::TooManyRequests => e
          if num_retries <= MAX_RETRIES
            if WAIT
              sleep e.rate_limit.reset_in
              num_retries += 1
              retry
            else
              logger.warn "retry #{e.rate_limit.reset_in} seconds later, #{e.inspect}"
            end
          else
            logger.warn "fail. num_retries > MAX_RETRIES(=#{MAX_RETRIES}), #{e.inspect}"
          end
        rescue => e
          if num_retries <= MAX_RETRIES
            logger.warn "retry till num_retries > MAX_RETRIES(=#{MAX_RETRIES}), #{e.inspect}"
            num_retries += 1
            retry
          else
            logger.warn "fail. num_retries > MAX_RETRIES(=#{MAX_RETRIES}), something error #{e.inspect}"
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

  # Returns tweets that match a specified query.
  #
  # @see https://dev.twitter.com/docs/api/1.1/get/search/tweets
  # @see https://dev.twitter.com/docs/using-search
  # @note Please note that Twitter's search service and, by extension, the Search API is not meant to be an exhaustive source of Tweets. Not all Tweets will be indexed or made available via the search interface.
  # @rate_limited Yes
  # @authentication Requires user context
  # @raise [Twitter::Error::Unauthorized] Error raised when supplied user credentials are not valid.
  # @param q [String] A search term. (from|to):hello min_retweets:3 OR min_faves:3 OR min_replies:3, #nhk @hello (in|ex)clude:retweets https://twitter.com/search-advanced
  # @param options [Hash] A customizable set of options.
  # @option options [String] :geocode Returns tweets by users located within a given radius of the given latitude/longitude. The location is preferentially taking from the Geotagging API, but will fall back to their Twitter profile. The parameter value is specified by "latitude,longitude,radius", where radius units must be specified as either "mi" (miles) or "km" (kilometers). Note that you cannot use the near operator via the API to geocode arbitrary locations; however you can use this geocode parameter to search near geocodes directly.
  # @option options [String] :lang Restricts tweets to the given language, given by an ISO 639-1 code.
  # @option options [String] :locale Specify the language of the query you are sending (only ja is currently effective). This is intended for language-specific clients and the default should work in the majority of cases.
  # @option options [String] :result_type Specifies what type of search results you would prefer to receive. Options are "mixed", "recent", and "popular". The current default is "mixed."
  # @option options [Integer] :count The number of tweets to return per page, up to a maximum of 100.
  # @option options [String] :until Optional. Returns tweets generated before the given date. Date should be formatted as YYYY-MM-DD.
  # @option options [Integer] :since_id Returns results with an ID greater than (that is, more recent than) the specified ID. There are limits to the number of Tweets which can be accessed through the API. If the limit of Tweets has occured since the since_id, the since_id will be forced to the oldest ID available.
  # @option options [Integer] :max_id Returns results with an ID less than (that is, older than) or equal to the specified ID.
  # @return [Twitter::SearchResults] Return tweets that match a specified query with search metadata
  alias :old_search :search
  def search(*args)
    options = {count: 100, result_type: 'recent'}.merge(args.extract_options!)
    collect_with_max_id(:old_search, *args, options) do |data, last_response|
      statuses = last_response.attrs[:statuses]
      data.concat(statuses)
      statuses
    end
  end

  # mentions_timeline is to fetch the timeline of Tweets mentioning the authenticated user
  # get_mentions is to fetch the Tweets mentioning the screen_name's user
  def get_mentions(screen_name)
    search("to:#{screen_name}")
  end

  def search_japanese_tweets(str)
    search(str, {lang: 'ja'})
  end

  def search_tweets_except_rt(str)
    search("#{str} exclude:retweets")
  end
end


