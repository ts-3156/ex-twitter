require 'twitter_with_auto_pagination/rest/utils'
require 'parallel'

module TwitterWithAutoPagination
  module REST
    module Extension
      module FriendsAndFollowers
        include TwitterWithAutoPagination::REST::Utils

        def _fetch_parallelly(signatures) # [{method: :friends, args: ['ts_3156', ...], {...}]
          result = Array.new(signatures.size)

          Parallel.each_with_index(signatures, in_threads: result.size) do |signature, i|
            result[i] = send(signature[:method], *signature[:args])
          end

          result
        end

        def friends_followers_and_statuses(*args)
          _fetch_parallelly(
            [
              {method: :friends, args: args},
              {method: :followers, args: args},
              {method: :user_timeline, args: args}])
        end

        def _retrieve_friends_and_followers(*args)
          obj = args[0]
          if obj.nil?
            friends_and_followers
          elsif uid_or_screen_name?(obj)
            friends_and_followers(obj)
          elsif obj.respond_to?(:friends) && obj.respond_to?(:followers)
            [obj.friends, obj.followers]
          else
            raise ArgumentError, args.inspect
          end
        end

        def one_sided_friends(me = nil)
          instrument(__method__, nil) do
            _friends, _followers = _retrieve_friends_and_followers(me)
            _friends.to_a - _followers.to_a
          end
        end

        def one_sided_followers(me = nil)
          instrument(__method__, nil) do
            _friends, _followers = _retrieve_friends_and_followers(me)
            _followers.to_a - _friends.to_a
          end
        end

        def mutual_friends(me = nil)
          instrument(__method__, nil) do
            _friends, _followers = _retrieve_friends_and_followers(me)
            _friends.to_a & _followers.to_a
          end
        end

        def _retrieve_friends(*args)
          if args.size == 1
            args[0].nil? ? friends : friends(args[0])
          elsif args.all? { |obj| uid_or_screen_name?(obj) }
            _fetch_parallelly(args.map { |obj| {method: :friends, args: [obj]} })
          elsif args.all? { |obj| obj.respond_to?(:friends) }
            args.map { |obj| obj.friends }
          else
            raise ArgumentError, args.inspect
          end
        end

        def common_friends(me, you)
          instrument(__method__, nil) do
            my_friends, your_friends = _retrieve_friends(me, you)
            my_friends.to_a & your_friends.to_a
          end
        end

        def _retrieve_followers(*args)
          if args.size == 1
            args[0].nil? ? followers : followers(args[0])
          elsif args.all? { |obj| uid_or_screen_name?(obj) }
            _fetch_parallelly(args.map { |obj| {method: :followers, args: [obj]} })
          elsif args.all? { |obj| obj.respond_to?(:followers) }
            args.map { |obj| obj.followers }
          else
            raise ArgumentError, args.inspect
          end
        end

        def common_followers(me, you)
          instrument(__method__, nil) do
            my_followers, your_followers = _retrieve_followers(me, you)
            my_followers.to_a & your_followers.to_a
          end
        end

        def _extract_inactive_users(users)
          two_weeks_ago = 2.weeks.ago.to_i
          users.select do |u|
            (Time.parse(u.status.created_at).to_i < two_weeks_ago) rescue false
          end
        end

        def inactive_friends(user = nil)
          instrument(__method__, nil) do
            _friends = _retrieve_friends(user)
            _extract_inactive_users(_friends)
          end
        end

        def inactive_followers(user = nil)
          instrument(__method__, nil) do
            _followers = _retrieve_followers(user)
            _extract_inactive_users(_followers)
          end
        end
      end
    end
  end
end

