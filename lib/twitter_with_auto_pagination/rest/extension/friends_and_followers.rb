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

        def friends_and_followers(*args)
          _fetch_parallelly(
            [
              {method: :friends, args: args},
              {method: :followers, args: args}])
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
            raise ArgumentError
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

        def common_friends(me, you)
          instrument(__method__, nil) do
            my_friends, your_friends =
              if uid_or_screen_name?(me) && uid_or_screen_name?(you)
                _fetch_parallelly([{method: :friends, args: [me]}, {method: :friends, args: [you]}])
              elsif me.respond_to?(:friends) && you.respond_to?(:friends)
                [me.friends, you.friends]
              else
                raise ArgumentError
              end

            my_friends.to_a & your_friends.to_a
          end
        end

        def common_followers(me, you)
          instrument(__method__, nil) do
            my_followers, your_followers =
              if uid_or_screen_name?(me) && uid_or_screen_name?(you)
                _fetch_parallelly([{method: :followers, args: [me]}, {method: :followers, args: [you]}])
              elsif me.respond_to?(:followers) && you.respond_to?(:followers)
                [me.followers, you.followers]
              else
                raise ArgumentError
              end

            my_followers.to_a & your_followers.to_a
          end
        end
      end
    end
  end
end

