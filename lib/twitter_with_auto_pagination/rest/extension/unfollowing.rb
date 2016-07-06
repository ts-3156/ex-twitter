require 'twitter_with_auto_pagination/rest/utils'

module TwitterWithAutoPagination
  module REST
    module Extension
      module Unfollowing
        include TwitterWithAutoPagination::REST::Utils

        def users_which_you_removed(past_me, cur_me)
          instrument(__method__, nil) do
            past_friends, cur_friends = _retrieve_friends(past_me, cur_me)
            past_friends.to_a - cur_friends.to_a
          end
        end

        alias removing users_which_you_removed
        alias unfollowing users_which_you_removed

        def users_who_removed_you(past_me, cur_me)
          instrument(__method__, nil) do
            past_followers, cur_followers = _retrieve_followers(past_me, cur_me)
            past_followers.to_a - cur_followers.to_a
          end
        end

        alias removed users_who_removed_you
        alias unfollowed users_who_removed_you
      end
    end
  end
end
