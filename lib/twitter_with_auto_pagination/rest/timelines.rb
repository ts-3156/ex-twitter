require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Timelines
      include TwitterWithAutoPagination::REST::Utils

      def home_timeline(*args)
        options = {count: 200, include_rts: true, call_limit: 3}.merge(args.extract_options!)
        fetch_cache_or_call_api(__method__, user.id, options) {
          collect_with_max_id("old_#{__method__}", options)
        }
      end

      def user_timeline(*args)
        options = {count: 200, include_rts: true, call_limit: 3}.merge(args.extract_options!)
        args[0] = verify_credentials.id if args.empty?
        fetch_cache_or_call_api(__method__, args[0], options) {
          collect_with_max_id("old_#{__method__}", *args, options)
        }
      end

      def mentions_timeline(*args)
        options = {count: 200, include_rts: true, call_limit: 1}.merge(args.extract_options!)
        fetch_cache_or_call_api(__method__, user.id, options) {
          collect_with_max_id("old_#{__method__}", options)
        }
      end
    end
  end
end