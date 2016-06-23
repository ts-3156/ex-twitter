require 'active_support'
require 'active_support/cache'
require 'active_support/core_ext/string'

require 'log_subscriber'
require 'utils'
require 'existing_api'

require 'twitter'
require 'hashie'
require 'parallel'



class ExTwitter < Twitter::REST::Client

  def initialize(options = {})
    @cache = ActiveSupport::Cache::FileStore.new(File.join('tmp', 'api_cache'))
    @uid = options[:uid]
    @screen_name = options[:screen_name]
    @authenticated_user = Hashie::Mash.new({uid: options[:uid].to_i, screen_name: options[:screen_name]})
    @call_count = 0
    LogSubscriber.attach_to :ex_twitter
    @@logger = @logger =
      if options[:logger]
        options.delete(:logger)
      else
        Dir.mkdir('log') unless File.exists?('log')
        Logger.new('log/ex_twitter.log')
      end
    super
  end

  def self.logger
    @@logger
  end

  attr_accessor :call_count
  attr_reader :cache, :authenticated_user, :logger

  INDENT = 4

  include Utils

  alias :old_friendship? :friendship?
  alias :old_user? :user?
  alias :old_user :user
  alias :old_friend_ids :friend_ids
  alias :old_follower_ids :follower_ids
  alias :old_friends :friends
  alias :old_followers :followers
  alias :old_users :users
  alias :old_home_timeline :home_timeline
  alias :old_user_timeline :user_timeline
  alias :old_mentions_timeline :mentions_timeline
  alias :old_favorites :favorites
  alias :old_search :search

  include ExistingApi

  def friends_advanced(*args)
    options = args.extract_options!
    _friend_ids = friend_ids(*(args + [options]))
    users(_friend_ids.map { |id| id.to_i }, options)
  end

  def followers_advanced(*args)
    options = args.extract_options!
    _follower_ids = follower_ids(*(args + [options]))
    users(_follower_ids.map { |id| id.to_i }, options)
  end

  def fetch_parallelly(signatures) # [{method: :friends, args: ['ts_3156', ...], {...}]
    logger.debug "#{__method__} #{signatures.inspect}"
    result = Array.new(signatures.size)

    Parallel.each_with_index(signatures, in_threads: result.size) do |signature, i|
      result[i] = send(signature[:method], *signature[:args])
    end

    result
  end

  def friends_and_followers(*args)
    fetch_parallelly(
      [
        {method: 'friends_advanced', args: args},
        {method: 'followers_advanced', args: args}])
  end

  def friends_followers_and_statuses(*args)
    fetch_parallelly(
      [
        {method: 'friends_advanced', args: args},
        {method: 'followers_advanced', args: args},
        {method: 'user_timeline', args: args}])
  end

  def one_sided_following(me)
    me.friends.to_a - me.followers.to_a
  end

  def one_sided_followers(me)
    me.followers.to_a - me.friends.to_a
  end

  def mutual_friends(me)
    me.friends.to_a & me.followers.to_a
  end

  def common_friends(me, you)
    me.friends.to_a & you.friends.to_a
  end

  def common_followers(me, you)
    me.followers.to_a & you.followers.to_a
  end

  def removing(pre_me, cur_me)
    pre_me.friends.to_a - cur_me.friends.to_a
  end

  def removed(pre_me, cur_me)
    pre_me.followers.to_a - cur_me.followers.to_a
  end

  def _select_screen_names_replied(tweets, options = {})
    result = tweets.map do |t|
      $1 if t.text =~ /^(?:\.)?@(\w+)( |\W)/ # include statuses starts with .
    end.compact
    (options.has_key?(:uniq) && !options[:uniq]) ? result : result.uniq
  end

  # users which specified user is replying
  # in_reply_to_user_id and in_reply_to_status_id is not used because of distinguishing mentions from replies
  def replying(user, options = {})
    tweets = options.has_key?(:tweets) ? options.delete(:tweets) : user_timeline(user, options)
    screen_names = _select_screen_names_replied(tweets, options)
    users(screen_names, options)
  rescue Twitter::Error::NotFound => e
    e.message == 'No user matches for specified terms.' ? [] : (raise e)
  rescue => e
    logger.warn "#{__method__} #{user.inspect} #{e.class} #{e.message}"
    raise e
  end

  def _select_uids_replying_to(tweets, options)
    result = tweets.map do |t|
      t.user.id.to_i if t.text =~ /^(?:\.)?@(\w+)( |\W)/ # include statuses starts with .
    end.compact
    (options.has_key?(:uniq) && !options[:uniq]) ? result : result.uniq
  end

  def select_replied_from_search(tweets, options = {})
    return [] if tweets.empty?
    uids = _select_uids_replying_to(tweets, options)
    uids.map { |u| tweets.find { |t| t.user.id.to_i == u.to_i } }.map { |t| t.user }
  end

  # users which specified user is replied
  # when user is login you had better to call mentions_timeline
  def replied(_user, options = {})
    user = self.user(_user, options)
    if user.id.to_i == __uid_i
      mentions_timeline(__uid_i, options).uniq { |m| m.user.id }.map { |m| m.user }
    else
      select_replied_from_search(search('@' + user.screen_name, options))
    end
  rescue => e
    logger.warn "#{__method__} #{_user.inspect} #{e.class} #{e.message}"
    raise e
  end

  def _select_inactive_users(users, options = {})
    options[:authorized] = false unless options.has_key?(:authorized)
    two_weeks_ago = 2.weeks.ago.to_i
    users.select do |u|
      if options[:authorized] || !u.protected
        (Time.parse(u.status.created_at).to_i < two_weeks_ago) rescue false
      else
        false
      end
    end
  end

  def inactive_friends(user)
    _select_inactive_users(friends_advanced(user))
  end

  def inactive_followers(user)
    _select_inactive_users(followers_advanced(user))
  end

  def clusters_belong_to(text)
    return [] if text.blank?

    exclude_words = JSON.parse(File.read(Rails.configuration.x.constants['cluster_bad_words_path']))
    special_words = JSON.parse(File.read(Rails.configuration.x.constants['cluster_good_words_path']))

    # クラスタ用の単語の出現回数を記録
    cluster_word_counter =
      special_words.map { |sw| [sw, text.scan(sw)] }
        .delete_if { |item| item[1].empty? }
        .each_with_object(Hash.new(1)) { |item, memo| memo[item[0]] = item[1].size }

    # 同一文字種の繰り返しを見付ける。漢字の繰り返し、ひらがなの繰り返し、カタカナの繰り返し、など
    text.scan(/[一-龠〆ヵヶ々]+|[ぁ-んー～]+|[ァ-ヴー～]+|[ａ-ｚＡ-Ｚ０-９]+|[、。！!？?]+/).

      # 複数回繰り返される文字を除去
      map { |w| w.remove /[？！?!。、ｗ]|(ー{2,})/ }.

      # 文字数の少なすぎる単語、ひらがなだけの単語、除外単語を除去する
      delete_if { |w| w.length <= 1 || (w.length <= 2 && w =~ /^[ぁ-んー～]+$/) || exclude_words.include?(w) }.

      # 出現回数を記録
      each { |w| cluster_word_counter[w] += 1 }

    # 複数個以上見付かった単語のみを残し、出現頻度順にソート
    cluster_word_counter.select { |_, v| v > 3 }.sort_by { |_, v| -v }.to_h
  end

  def clusters_assigned_to

  end

  def usage_stats_wday_series_data(times)
    wday_count = times.each_with_object((0..6).map { |n| [n, 0] }.to_h) do |time, memo|
      memo[time.wday] += 1
    end
    wday_count.map { |k, v| [I18n.t('date.abbr_day_names')[k], v] }.map do |key, value|
      {name: key, y: value, drilldown: key}
    end
  end

  def usage_stats_wday_drilldown_series(times)
    hour_count =
      (0..6).each_with_object((0..6).map { |n| [n, nil] }.to_h) do |wday, wday_memo|
        wday_memo[wday] =
          times.select { |t| t.wday == wday }.map { |t| t.hour }.each_with_object((0..23).map { |n| [n, 0] }.to_h) do |hour, hour_memo|
            hour_memo[hour] += 1
          end
      end
    hour_count.map { |k, v| [I18n.t('date.abbr_day_names')[k], v] }.map do |key, value|
      {name: key, id: key, data: value.to_a.map{|a| [a[0].to_s, a[1]] }}
    end
  end

  def usage_stats_hour_series_data(times)
    hour_count = times.each_with_object((0..23).map { |n| [n, 0] }.to_h) do |time, memo|
      memo[time.hour] += 1
    end
    hour_count.map do |key, value|
      {name: key.to_s, y: value, drilldown: key.to_s}
    end
  end

  def usage_stats_hour_drilldown_series(times)
    wday_count =
      (0..23).each_with_object((0..23).map { |n| [n, nil] }.to_h) do |hour, hour_memo|
        hour_memo[hour] =
          times.select { |t| t.hour == hour }.map { |t| t.wday }.each_with_object((0..6).map { |n| [n, 0] }.to_h) do |wday, wday_memo|
            wday_memo[wday] += 1
          end
      end
    wday_count.map do |key, value|
      {name: key.to_s, id: key.to_s, data: value.to_a.map{|a| [I18n.t('date.abbr_day_names')[a[0]], a[1]] }}
    end
  end

  def twitter_addiction_series(times)
    five_mins = 5.minutes
    wday_expended_seconds =
      (0..6).each_with_object((0..6).map { |n| [n, nil] }.to_h) do |wday, wday_memo|
        target_times = times.select { |t| t.wday == wday }
        wday_memo[wday] = target_times.empty? ? nil : target_times.each_cons(2).map {|a, b| (a - b) < five_mins ? a - b : five_mins }.sum
      end
    days = times.map{|t| t.to_date.to_s(:long) }.uniq.size
    weeks = (days > 7) ? days / 7.0 : 1.0
    wday_expended_seconds.map { |k, v| [I18n.t('date.abbr_day_names')[k], (v.nil? ? nil : v / weeks / 60)] }.map do |key, value|
      {name: key, y: value}
    end
  end

  def usage_stats(user, options = {})
    n_days_ago = options.has_key?(:days) ? options[:days].days.ago : 100.years.ago
    tweets = options.has_key?(:tweets) ? options.delete(:tweets) : user_timeline(user)
    times =
      # TODO Use user specific time zone
      tweets.map { |t| ActiveSupport::TimeZone['Tokyo'].parse(t.created_at.to_s) }.
        select { |t| t > n_days_ago }
    [
      usage_stats_wday_series_data(times),
      usage_stats_wday_drilldown_series(times),
      usage_stats_hour_series_data(times),
      usage_stats_hour_drilldown_series(times),
      twitter_addiction_series(times)
    ]
  end


  def calc_scores_from_users(users, options)
    min = options.has_key?(:min) ? options[:min] : 0
    max = options.has_key?(:max) ? options[:max] : 1000
    users.each_with_object(Hash.new(0)) { |u, memo| memo[u.id] += 1 }.
      select { |_k, v| min <= v && v <= max }.
      sort_by { |_, v| -v }.to_h
  end

  def calc_scores_from_tweets(tweets, options = {})
    calc_scores_from_users(tweets.map { |t| t.user }, options)
  end

  def select_favoriting_from_favs(favs, options = {})
    return [] if favs.empty?
    uids = calc_scores_from_tweets(favs)
    result = uids.map { |uid, score| f = favs.
      find { |f| f.user.id.to_i == uid.to_i }; Array.new(score, f) }.flatten.map { |f| f.user }
    (options.has_key?(:uniq) && !options[:uniq]) ? result : result.uniq { |u| u.id }
  end

  def favoriting(user, options= {})
    favs = options.has_key?(:favorites) ? options.delete(:favorites) : favorites(user, options)
    select_favoriting_from_favs(favs, options)
  rescue => e
    logger.warn "#{__method__} #{user.inspect} #{e.class} #{e.message}"
    raise e
  end

  def favorited_by(user)
  end

  def close_friends(_uid, options = {})
    min = options.has_key?(:min) ? options[:min] : 0
    max = options.has_key?(:max) ? options[:max] : 1000
    uid_i = _uid.to_i
    _replying = options.has_key?(:replying) ? options.delete(:replying) : replying(uid_i, options)
    _replied = options.has_key?(:replied) ? options.delete(:replied) : replied(uid_i, options)
    _favoriting = options.has_key?(:favoriting) ? options.delete(:favoriting) : favoriting(uid_i, options)

    min_max = {min: min, max: max}
    _users = _replying + _replied + _favoriting
    return [] if _users.empty?

    scores = calc_scores_from_users(_users, min_max)
    replying_scores = calc_scores_from_users(_replying, min_max)
    replied_scores = calc_scores_from_users(_replied, min_max)
    favoriting_scores = calc_scores_from_users(_favoriting, min_max)

    scores.keys.map { |uid| _users.find { |u| u.id.to_i == uid.to_i } }.
      map do |u|
      u[:score] = scores[u.id]
      u[:replying_score] = replying_scores[u.id]
      u[:replied_score] = replied_scores[u.id]
      u[:favoriting_score] = favoriting_scores[u.id]
      u
    end
  end
end