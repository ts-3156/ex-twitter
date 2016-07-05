require 'twitter_with_auto_pagination/rest/favorites'
require 'twitter_with_auto_pagination/rest/friends_and_followers'
require 'twitter_with_auto_pagination/rest/search'
require 'twitter_with_auto_pagination/rest/timelines'
require 'twitter_with_auto_pagination/rest/users'
require 'twitter_with_auto_pagination/rest/uncategorized'

module TwitterWithAutoPagination
  module REST
    module API
      include TwitterWithAutoPagination::REST::Favorites
      include TwitterWithAutoPagination::REST::FriendsAndFollowers
      include TwitterWithAutoPagination::REST::Search
      include TwitterWithAutoPagination::REST::Timelines
      include TwitterWithAutoPagination::REST::Users
      include TwitterWithAutoPagination::REST::Uncategorized
    end
  end
end