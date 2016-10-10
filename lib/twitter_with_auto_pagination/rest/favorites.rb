require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Favorites
      include TwitterWithAutoPagination::REST::Utils

      def favorites(*args)
        options = {count: 100, call_limit: 3}.merge(args.extract_options!)
        args[0] = verify_credentials(super_operation: __method__).id if args.empty?
        instrument(__method__, nil, options) do
          fetch_cache_or_call_api(__method__, args[0], options) do
            collect_with_max_id(method(__method__).super_method, *args, options).map { |s| s.attrs }
          end
        end
      end
    end
  end
end
