require 'dotenv/load'
require 'twitter_with_auto_pagination'
require 'oj'
require 'benchmark'

client =
  TwitterWithAutoPagination::Client.new(
    consumer_key: ENV['CK'],
    consumer_secret: ENV['CS'],
    access_token: ENV['AT'],
    access_token_secret: ENV['ATS']
  )

followers = client.followers
puts "size #{followers.size}"

N = 100

Benchmark.bm(4) do |r|
  r.report 'JSON' do
    N.times.each do
      str = JSON.dump(followers)
      JSON.parse(str, symbolize_names: true)
    end
  end

  r.report 'OJ' do
    N.times.each do
      str = Oj.dump(followers)
      Oj.load(str, symbolize_names: true)
    end
  end
end