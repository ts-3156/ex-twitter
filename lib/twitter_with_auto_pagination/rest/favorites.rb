require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Favorites
      include TwitterWithAutoPagination::REST::Utils

      MAX_TWEETS_PER_REQUEST = 100

      %i(favorites).each do |name|
        define_method(name) do |*args|
          options = args.extract_options!
          call_limit = calc_call_limit(options.delete(:count), MAX_TWEETS_PER_REQUEST)
          options = {count: MAX_TWEETS_PER_REQUEST, result_type: :recent, call_count: 0, call_limit: call_limit}.merge(options)

          collect_with_max_id do |max_id|
            options[:max_id] = max_id unless max_id.nil?
            options[:call_count] += 1
            twitter.send(name, *args, options) if options[:call_count] <= options[:call_limit]
          end.map(&:attrs)
        end
      end
    end
  end
end
