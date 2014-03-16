# -*- coding: utf-8 -*-
require 'twitter'
require 'yaml'

# extended twitter
class ExTwitter < Twitter::REST::Client
  def initialize(config)
    super
  end

  MAX_ATTEMPTS = 3

  def collect_with_max_id(collection=[], max_id=nil, &block)
    response = yield(max_id)
    collection += response
    response.empty? ? collection.flatten : collect_with_max_id(collection, response.last.id - 1, &block)
  end

  def get_all_tweets(user)
    num_attempts = 0
    collect_with_max_id do |max_id|
      options = {count: 200, include_rts: true}
      options[:max_id] = max_id unless max_id.nil?
      begin
        num_attempts += 1
        user_timeline(user, options)
      rescue Twitter::Error::TooManyRequests => e
        if num_attempts <= MAX_ATTEMPTS
          sleep e.rate_limit.reset_in
        else
          raise
        end
      end
    end
  end
end

if __FILE__ == $0
  yml_config = YAML.load_file('config.yml')
  config = {
    consumer_key: yml_config['consumer_key'],
    consumer_secret: yml_config['consumer_secret'],
    access_token: yml_config['access_token'],
    access_token_secret: yml_config['access_token_secret']
  }
  client = ExTwitter.new(config)
  puts client.friends.first.screen_name
end


