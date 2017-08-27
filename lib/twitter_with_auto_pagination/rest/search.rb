require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Search
      include TwitterWithAutoPagination::REST::Utils

      MAX_TWEETS_PER_REQUEST = 100

      %i(search).each do |name|
        define_method(name) do |query, options = {}|
          raise ArgumentError.new('specify a query') unless query.is_a?(String)

          call_limit = calc_call_limit(options.delete(:count), MAX_TWEETS_PER_REQUEST)
          options = {count: MAX_TWEETS_PER_REQUEST, result_type: :recent, call_count: 0, call_limit: call_limit}.merge(options)

          collect_with_max_id do |max_id|
            options[:max_id] = max_id unless max_id.nil?
            options[:call_count] += 1
            if options[:call_count] <= options[:call_limit]
              twitter.send(name, query, options).attrs[:statuses].map { |s| Twitter::Tweet.new(s) }
            end
          end.map(&:attrs)
        end
      end
    end
  end
end