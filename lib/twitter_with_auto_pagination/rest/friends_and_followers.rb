require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module FriendsAndFollowers
      include TwitterWithAutoPagination::REST::Utils

      def friendship?(*args)
        options = args.extract_options!
        fetch_cache_or_call_api(__method__, args) {
          call_api(method(__method__).super_method, *args, options)
        }
      end

      def friend_ids(*args)
        options = {count: 5000, cursor: -1}.merge(args.extract_options!)
        args[0] = verify_credentials.id if args.empty?
        fetch_cache_or_call_api(__method__, args[0], options) {
          collect_with_cursor(method(__method__).super_method, *args, options)
        }
      end

      def follower_ids(*args)
        options = {count: 5000, cursor: -1}.merge(args.extract_options!)
        args[0] = verify_credentials.id if args.empty?
        fetch_cache_or_call_api(__method__, args[0], options) {
          collect_with_cursor(method(__method__).super_method, *args, options)
        }
      end

      # specify reduce: false to use tweet for inactive_*
      def friends(*args)
        options = args.extract_options!
        if options.delete(:serial)
          _friends_serially(*args, options)
        else
          _friends_parallelly(*args, options)
        end
      end

      def _friends_serially(*args)
        options = {count: 200, include_user_entities: true, cursor: -1}.merge(args.extract_options!)
        options[:reduce] = false unless options.has_key?(:reduce)
        args[0] = verify_credentials.id if args.empty?
        fetch_cache_or_call_api(:friends, args[0], options) {
          collect_with_cursor(method(:friends).super_method, *args, options)
        }
      end

      def _friends_parallelly(*args)
        options = {super_operation: __method__}.merge(args.extract_options!)
        users(friend_ids(*args, options).map { |id| id.to_i }, options)
      end

      # specify reduce: false to use tweet for inactive_*
      def followers(*args)
        options = args.extract_options!
        if options.delete(:serial)
          _followers_serially(*args, options)
        else
          _followers_parallelly(*args, options)
        end
      end

      def _followers_serially(*args)
        options = {count: 200, include_user_entities: true, cursor: -1}.merge(args.extract_options!)
        options[:reduce] = false unless options.has_key?(:reduce)
        args[0] = verify_credentials.id if args.empty?
        fetch_cache_or_call_api(:followers, args[0], options) {
          collect_with_cursor(method(:followers).super_method, *args, options)
        }
      end

      def _followers_parallelly(*args)
        options = {super_operation: __method__}.merge(args.extract_options!)
        users(follower_ids(*args, options).map { |id| id.to_i }, options)
      end
    end
  end
end