require 'active_support'
require 'active_support/cache'
require 'active_support/core_ext/string'

require 'twitter_with_auto_pagination/log_subscriber'
require 'twitter_with_auto_pagination/utils'
require 'twitter_with_auto_pagination/existing_api'
require 'twitter_with_auto_pagination/new_api'

require 'twitter'
require 'hashie'
require 'parallel'

module TwitterWithAutoPagination
  class Client < Twitter::REST::Client
    def initialize(options = {})
      @cache = ActiveSupport::Cache::FileStore.new(File.join('tmp', 'api_cache'))
      @call_count = 0

      @uid = options.has_key?(:uid) ? options.delete(:uid).to_i : nil
      @screen_name = options.has_key?(:screen_name) ? options.delete(:screen_name).to_s : nil

      @@logger = @logger =
        if options[:logger]
          options.delete(:logger)
        else
          Dir.mkdir('log') unless File.exists?('log')
          Logger.new('log/twitter_with_auto_pagination.log')
        end

      super
    end

    def self.logger
      @@logger
    end

    attr_accessor :call_count
    attr_reader :cache, :authenticated_user, :logger

    INDENT = 4

    include TwitterWithAutoPagination::Utils

    alias :old_verify_credentials :verify_credentials
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

    include TwitterWithAutoPagination::ExistingApi
    include TwitterWithAutoPagination::NewApi

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
  end
end