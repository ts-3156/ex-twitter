require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Timelines
      include TwitterWithAutoPagination::REST::Utils

      def home_timeline(*args)
        mtd = __method__
        options = {count: 200, include_rts: true, call_limit: 3}.merge(args.extract_options!)
        instrument(mtd, nil, options) do
          fetch_cache_or_call_api(mtd, verify_credentials(super_operation: mtd).id, options) do
            collect_with_max_id(method(mtd).super_method, options).map { |s| s.attrs }
          end
        end
      end

      def user_timeline(*args)
        mtd = __method__
        options = {count: 200, include_rts: true, call_limit: 3}.merge(args.extract_options!)
        args[0] = verify_credentials(super_operation: mtd).id if args.empty?
        instrument(mtd, nil, options) do
          fetch_cache_or_call_api(mtd, args[0], options) do
            collect_with_max_id(method(mtd).super_method, *args, options).map { |s| s.attrs }
          end
        end
      end

      def mentions_timeline(*args)
        mtd = __method__
        options = {count: 200, include_rts: true, call_limit: 1}.merge(args.extract_options!)
        instrument(mtd, nil, options) do
          fetch_cache_or_call_api(mtd, verify_credentials(super_operation: mtd).id, options) do
            collect_with_max_id(method(mtd).super_method, options).map { |s| s.attrs }
          end
        end
      end
    end
  end
end
