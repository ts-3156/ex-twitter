require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module FriendsAndFollowers
      include TwitterWithAutoPagination::REST::Utils

      def friendship?(*args)
        options = args.extract_options!
        fetch_cache_or_call_api(__method__, args) {
          call_old_method("old_#{__method__}", *args, options)
        }
      end

      def friend_ids(*args)
        options = {count: 5000, cursor: -1}.merge(args.extract_options!)
        args[0] = verify_credentials(skip_status: true).id if args.empty?
        fetch_cache_or_call_api(__method__, args[0], options) {
          collect_with_cursor("old_#{__method__}", *args, options)
        }
      end

      def follower_ids(*args)
        options = {count: 5000, cursor: -1}.merge(args.extract_options!)
        args[0] = verify_credentials(skip_status: true).id if args.empty?
        fetch_cache_or_call_api(__method__, args[0], options) {
          collect_with_cursor("old_#{__method__}", *args, options)
        }
      end

      # specify reduce: false to use tweet for inactive_*
      def friends(*args)
        options = {count: 200, include_user_entities: true, cursor: -1}.merge(args.extract_options!)
        options[:reduce] = false unless options.has_key?(:reduce)
        args[0] = verify_credentials(skip_status: true).id if args.empty?
        fetch_cache_or_call_api(__method__, args[0], options) {
          collect_with_cursor("old_#{__method__}", *args, options)
        }
      end

      # specify reduce: false to use tweet for inactive_*
      def followers(*args)
        options = {count: 200, include_user_entities: true, cursor: -1}.merge(args.extract_options!)
        options[:reduce] = false unless options.has_key?(:reduce)
        args[0] = verify_credentials(skip_status: true).id if args.empty?
        fetch_cache_or_call_api(__method__, args[0], options) {
          collect_with_cursor("old_#{__method__}", *args, options)
        }
      end
    end
  end
end