require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Timelines
      include TwitterWithAutoPagination::REST::Utils

      def home_timeline(*args)
        options = {count: 200, include_rts: true, call_limit: 3}.merge(args.extract_options!)
        instrument(__method__, nil, options) do
          fetch_cache_or_call_api(__method__, verify_credentials.id, options) do
            collect_with_max_id(method(__method__).super_method, options)
          end
        end
      end

      def user_timeline(*args)
        options = {count: 200, include_rts: true, call_limit: 3}.merge(args.extract_options!)
        args[0] = verify_credentials.id if args.empty?
        instrument(__method__, nil, options) do
          fetch_cache_or_call_api(__method__, args[0], options) do
            collect_with_max_id(method(__method__).super_method, *args, options)
          end
        end
      end

      def mentions_timeline(*args)
        options = {count: 200, include_rts: true, call_limit: 1}.merge(args.extract_options!)
        instrument(__method__, nil, options) do
          fetch_cache_or_call_api(__method__, verify_credentials.id, options) do
            collect_with_max_id(method(__method__).super_method, options)
          end
        end
      end
    end
  end
end