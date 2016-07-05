require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Favorites
      include TwitterWithAutoPagination::REST::Utils

      def favorites(*args)
        options = {count: 100, call_count: 1}.merge(args.extract_options!)
        args[0] = verify_credentials(skip_status: true).id if args.empty?
        fetch_cache_or_call_api(__method__, args[0], options) {
          collect_with_max_id("old_#{__method__}", *args, options)
        }
      end
    end
  end
end