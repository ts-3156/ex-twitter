# -*- coding: utf-8 -*-
require 'twitter'
require 'yaml'

# extended twitter
class ExTwitter < Twitter::REST::Client
  def initialize(config)
    super
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


