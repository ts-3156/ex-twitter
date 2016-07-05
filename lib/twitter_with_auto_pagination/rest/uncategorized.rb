require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Uncategorized
      include TwitterWithAutoPagination::REST::Utils

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
end