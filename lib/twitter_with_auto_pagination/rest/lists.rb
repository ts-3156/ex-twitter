require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Lists
      include TwitterWithAutoPagination::REST::Utils

      def memberships(*args)
        options = {count: 1000, cursor: -1}.merge(args.extract_options!)
        args[0] = verify_credentials.id if args.empty?
        instrument(__method__, nil, options) do
          fetch_cache_or_call_api(__method__, args[0], options) do
            collect_with_cursor(method(__method__).super_method, *args, options)
          end
        end
      end

      def list_members(*args)
        options = {count: 5000, skip_status: 1, cursor: -1}.merge(args.extract_options!)
        instrument(__method__, nil, options) do
          fetch_cache_or_call_api(__method__, args[0], options) do
            collect_with_cursor(method(__method__).super_method, *args, options)
          end
        end
      end
    end
  end
end