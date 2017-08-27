require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Timelines
      include TwitterWithAutoPagination::REST::Utils

      MAX_TWEETS_PER_REQUEST = 200

      %i(home_timeline user_timeline mentions_timeline).each do |name|
        define_method(name) do |*args|
          options = args.extract_options!.dup
          call_limit = calc_call_limit(options.delete(:count), MAX_TWEETS_PER_REQUEST)
          options = {count: MAX_TWEETS_PER_REQUEST, include_rts: true, call_count: 0, call_limit: call_limit}.merge(options)

          collect_with_max_id do |max_id|
            options[:max_id] = max_id unless max_id.nil?
            options[:call_count] += 1
            if options[:call_count] <= options[:call_limit]
              twitter.send(name, *args, options)
            end
          end.map(&:attrs)
        end
      end
    end
  end
end
