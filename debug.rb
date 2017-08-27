require 'dotenv/load'
require 'twitter_with_auto_pagination'

client =
  TwitterWithAutoPagination::Client.new(
    consumer_key: ENV['CK'],
    consumer_secret: ENV['CS'],
    access_token: ENV['AT'],
    access_token_secret: ENV['ATS']
  )

client.cache.clear

friend_ids = []
follower_ids = []
friends = []
followers = []

friend_ids << client.friend_ids
friend_ids << client.friend_ids # cache

follower_ids << client.follower_ids
follower_ids << client.follower_ids # cache

client.cache.clear

result = client.friend_ids_and_follower_ids
friend_ids << result[0]
follower_ids << result[1]

result = client.friend_ids_and_follower_ids # cache
friend_ids << result[0]
follower_ids << result[1]

client.cache.clear

friends << client.friends
friends << client.friends # cache

followers << client.followers
followers << client.followers # cache

client.cache.clear

result = client.friends_and_followers
friends << result[0]
followers << result[1]

result = client.friends_and_followers # cache
friends << result[0]
followers << result[1]

(friend_ids + friends.map { |f| f.map { |ff| ff[:id] } }).each_cons(2).all? { |front, behind| front == behind }
(follower_ids + followers.map { |f| f.map { |ff| ff[:id] } }).each_cons(2).all? { |front, behind| front == behind }

puts 'ok'