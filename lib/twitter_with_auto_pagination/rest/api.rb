require 'twitter_with_auto_pagination/rest/favorites'
require 'twitter_with_auto_pagination/rest/friends_and_followers'
require 'twitter_with_auto_pagination/rest/search'
require 'twitter_with_auto_pagination/rest/timelines'
require 'twitter_with_auto_pagination/rest/users'
require 'twitter_with_auto_pagination/rest/uncategorized'

require 'twitter_with_auto_pagination/rest/extension/clusters'
require 'twitter_with_auto_pagination/rest/extension/favoriting'
require 'twitter_with_auto_pagination/rest/extension/friends_and_followers'
require 'twitter_with_auto_pagination/rest/extension/replying'
require 'twitter_with_auto_pagination/rest/extension/unfollowing'
require 'twitter_with_auto_pagination/rest/extension/users'

module TwitterWithAutoPagination
  module REST
    module API
      include TwitterWithAutoPagination::REST::Favorites
      include TwitterWithAutoPagination::REST::FriendsAndFollowers
      include TwitterWithAutoPagination::REST::Search
      include TwitterWithAutoPagination::REST::Timelines
      include TwitterWithAutoPagination::REST::Users
      include TwitterWithAutoPagination::REST::Uncategorized

      include TwitterWithAutoPagination::REST::Extension::Clusters
      include TwitterWithAutoPagination::REST::Extension::Favoriting
      include TwitterWithAutoPagination::REST::Extension::FriendsAndFollowers
      include TwitterWithAutoPagination::REST::Extension::Replying
      include TwitterWithAutoPagination::REST::Extension::Unfollowing
      include TwitterWithAutoPagination::REST::Extension::Users
    end
  end
end