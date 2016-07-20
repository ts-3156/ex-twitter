require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module FriendsAndFollowers
      include TwitterWithAutoPagination::REST::Utils

      def friendship?(*args)
        options = args.extract_options!
        instrument(__method__, nil, options) do
          fetch_cache_or_call_api(__method__, args) do
            call_api(method(__method__).super_method, *args, options)
          end
        end
      end

      def friend_ids(*args)
        options = {count: 5000, cursor: -1}.merge(args.extract_options!)
        args[0] = verify_credentials.id if args.empty?
        instrument(__method__, nil, options) do
          fetch_cache_or_call_api(__method__, args[0], options) do
            collect_with_cursor(method(__method__).super_method, *args, options)
          end
        end
      end

      def follower_ids(*args)
        options = {count: 5000, cursor: -1}.merge(args.extract_options!)
        args[0] = verify_credentials.id if args.empty?
        instrument(__method__, nil, options) do
          fetch_cache_or_call_api(__method__, args[0], options) do
            collect_with_cursor(method(__method__).super_method, *args, options)
          end
        end
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
        args[0] = verify_credentials.id if args.empty?
        instrument(__method__, nil, options) do
          fetch_cache_or_call_api(:friends, args[0], options) do
            collect_with_cursor(method(:friends).super_method, *args, options).map { |u| u.to_hash }
          end
        end
      end

      def _friends_parallelly(*args)
        options = {super_operation: __method__}.merge(args.extract_options!)
        instrument(__method__, nil, options) do
          users(friend_ids(*args, options).map { |id| id.to_i }, options)
        end
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
        args[0] = verify_credentials.id if args.empty?
        instrument(__method__, nil, options) do
          fetch_cache_or_call_api(:followers, args[0], options) do
            collect_with_cursor(method(:followers).super_method, *args, options).map { |u| u.to_hash }
          end
        end
      end

      def _followers_parallelly(*args)
        options = {super_operation: __method__}.merge(args.extract_options!)
        instrument(__method__, nil, options) do
          users(follower_ids(*args, options).map { |id| id.to_i }, options)
        end
      end
    end
  end
end